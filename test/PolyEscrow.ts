import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { BigNumberish, keccak256 } from 'ethers';
import { IEscrow, convertEscrow as convertEscrow } from './util';
import { time } from '@nomicfoundation/hardhat-network-helpers';

const ONE_HOUR = 3600;
const ONE_DAY = 86400;

describe('PolyEscrow', function () {
    let securityContext: any;
    let systemSettings: any;
    let polyEscrow: any;
    let testToken: any;
    let arbitrationModule: any;
    let admin: HardhatEthersSigner;
    let nonOwner: HardhatEthersSigner;
    let payer1: HardhatEthersSigner;
    let payer2: HardhatEthersSigner;
    let receiver1: HardhatEthersSigner;
    let receiver2: HardhatEthersSigner;
    let vaultAddress: HardhatEthersSigner;
    let arbiter1: HardhatEthersSigner;
    let arbiter2: HardhatEthersSigner;
    let defaultFeeBps = 0;

    async function getBalance(address: any, isToken = false) {
        return isToken
            ? await await testToken.balanceOf(address)
            : await admin.provider.getBalance(address);
    }

    async function getEscrow(escrowId: string) {
        return convertEscrow(await polyEscrow.getEscrow(escrowId));
    }

    async function createEscrow(
        escrowId: string,
        payerAccount: HardhatEthersSigner,
        receiverAddress: string,
        amount: BigNumberish,
        isToken: boolean = false,
        arbiters: string[] = [],
        arbitersRequired: number = arbiters?.length ?? 0,
        startTime: number = 0,
        endTime: number = 0
    ): Promise<IEscrow> {
        if (isToken)
            await testToken
                .connect(payerAccount)
                .approve(polyEscrow.target, amount);

        await polyEscrow.connect(payerAccount).createEscrow({
            currency: isToken ? testToken.target : ethers.ZeroAddress,
            id: escrowId,
            receiver: receiverAddress,
            payer: payerAccount.address,
            arbiters,
            arbitersRequired,
            amount,
            startTime,
            endTime,
            arbitrationModule: ethers.ZeroAddress,
        });

        //return escrow
        return await getEscrow(escrowId);
    }

    async function placePayment(
        escrowId: string,
        payerAccount: HardhatEthersSigner,
        amount: BigNumberish,
        isToken: boolean = false
    ): Promise<IEscrow> {
        if (isToken) {
            await testToken
                .connect(payerAccount)
                .approve(polyEscrow.target, amount);

            await polyEscrow.connect(payerAccount).placePayment({
                escrowId: escrowId,
                currency: testToken.target,
                amount,
            });
        } else {
            await polyEscrow.connect(payerAccount).placePayment(
                {
                    escrowId: escrowId,
                    currency: ethers.ZeroAddress,
                    amount,
                },
                { value: amount }
            );
        }

        //return escrow
        const escrow = convertEscrow(await polyEscrow.getEscrow(escrowId));
        return escrow;
    }

    function verifyEscrow(escrow: IEscrow, expectedValues: any) {
        if (expectedValues.id) expect(escrow.id).to.equal(expectedValues.id);
        if (expectedValues.payer)
            expect(escrow.payer).to.equal(expectedValues.payer);
        if (expectedValues.receiver)
            expect(escrow.receiver).to.equal(expectedValues.receiver);
        if (expectedValues.amount != undefined)
            expect(BigInt(escrow.amount)).to.equal(
                BigInt(expectedValues.amount)
            );
        if (expectedValues.amountRefunded != undefined)
            expect(BigInt(escrow.amountRefunded)).to.equal(
                BigInt(expectedValues.amountRefunded)
            );
        if (expectedValues.amountReleased != undefined)
            expect(BigInt(escrow.amountReleased)).to.equal(
                BigInt(expectedValues.amountReleased)
            );
        if (expectedValues.amountPaid != undefined)
            expect(BigInt(escrow.amountPaid)).to.equal(
                BigInt(expectedValues.amountPaid)
            );
        if (expectedValues.currency)
            expect(escrow.currency).to.equal(expectedValues.currency);
        if (expectedValues.receiverReleased != undefined)
            expect(escrow.receiverReleased).to.equal(
                expectedValues.receiverReleased
            );
        if (expectedValues.payerReleased != undefined)
            expect(escrow.payerReleased).to.equal(expectedValues.payerReleased);
        if (expectedValues.released != undefined)
            expect(escrow.released).to.equal(expectedValues.released);
        if (expectedValues.fullyPaid != undefined)
            expect(escrow.fullyPaid).to.equal(expectedValues.fullyPaid);
        if (expectedValues.startTime != undefined)
            expect(escrow.startTime).to.equal(expectedValues.startTime);
        if (expectedValues.endTime != undefined)
            expect(escrow.endTime).to.equal(expectedValues.endTime);
        if (expectedValues.status != undefined)
            expect(escrow.status).to.equal(expectedValues.status);
        if (expectedValues.arbitersRequired != undefined)
            expect(escrow.arbitersRequired).to.equal(
                expectedValues.arbitersRequired
            );
        if (expectedValues.arbiters) {
            expect(escrow.arbiters?.length ?? 0).to.equal(
                expectedValues.arbiters.length
            );
            for (let n = 0; n < escrow.arbiters.length; n++) {
                expect(escrow.arbiters[n]).to.equal(expectedValues.arbiters[n]);
            }
        }
    }

    this.beforeEach(async () => {
        const [a1, a2, a3, a4, a5, a6, a7, a8, a9] =
            await hre.ethers.getSigners();
        admin = a1;
        nonOwner = a2;
        vaultAddress = a3;
        payer1 = a4;
        payer2 = a5;
        receiver1 = a6;
        receiver2 = a7;
        arbiter1 = a8;
        arbiter2 = a9;

        //deploy security context
        const SecurityContextFactory =
            await hre.ethers.getContractFactory('SecurityContext');
        securityContext = await SecurityContextFactory.deploy(admin.address);

        //deploy system settings
        const SystemSettingsFactory =
            await hre.ethers.getContractFactory('SystemSettings');
        systemSettings = await SystemSettingsFactory.deploy(
            securityContext.target,
            vaultAddress,
            defaultFeeBps
        );

        //deploy test token
        const TestTokenFactory =
            await hre.ethers.getContractFactory('TestToken');
        testToken = await TestTokenFactory.deploy('XYZ', 'ZYX');

        //deploy arbitration module
        const ArbitrationModuleFactory =
            await hre.ethers.getContractFactory('ArbitrationModule');
        arbitrationModule = await ArbitrationModuleFactory.deploy();

        //deploy polyEscrow
        const PolyEscrowFactory =
            await hre.ethers.getContractFactory('PolyEscrow');
        polyEscrow = await PolyEscrowFactory.deploy(
            securityContext.target,
            systemSettings.target,
            arbitrationModule.target
        );

        //grant token
        await testToken.mint(nonOwner, 10000000000);
        await testToken.mint(payer1, 10000000000);
        await testToken.mint(payer2, 10000000000);
    });

    describe('Deployment', function () {
        it('Properties at deployment are correct', async function () {
            expect(await polyEscrow.securityContext()).to.equal(
                securityContext.target
            );
            expect(await polyEscrow.settings()).to.equal(systemSettings.target);
            expect(await polyEscrow.defaultArbitrationModule()).to.equal(
                arbitrationModule.target
            );
        });
    });

    describe('Create Escrows', function () {
        describe('Happy Paths', function () {
            /**
             * Just tests that an escrow can be created, and its values read back (native currency)
             */
            it('can create a new native currency escrow', async function () {
                const amount = 10000000;
                const isToken = false;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');

                //escrow is created in contract with right values
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );
                verifyEscrow(escrow, {
                    id: escrowId,
                    payer: payer1.address,
                    receiver: receiver1.address,
                    arbiters: [],
                    arbitersRequired: 0,
                    amount,
                    currency: isToken ? testToken.target : ethers.ZeroAddress,
                    amountPaid: 0,
                    amountRefunded: 0,
                    amountReleased: 0,
                    startTime: 0,
                    endTime: 0,
                    status: 0,
                    fullyPaid: false,
                    payerReleased: false,
                    receiverReleased: false,
                    released: false,
                });
            });

            /**
             * Just tests that an escrow can be created, and its values read back (token currency)
             */
            it('can create a new token currency escrow', async function () {
                const amount = 10000000;
                const isToken = true;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');

                //escrow is logged in contract with right values
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );
                verifyEscrow(escrow, {
                    id: escrowId,
                    payer: payer1.address,
                    receiver: receiver1.address,
                    arbiters: [],
                    arbitersRequired: 0,
                    amount,
                    currency: isToken ? testToken.target : ethers.ZeroAddress,
                    amountPaid: 0,
                    amountRefunded: 0,
                    amountReleased: 0,
                    startTime: 0,
                    endTime: 0,
                    status: 0,
                    fullyPaid: false,
                    payerReleased: false,
                    receiverReleased: false,
                    released: false,
                });
            });

            it('can create an escrow with multiple arbiters', async function () {
                const amount = 10000000;
                const isToken = false;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');

                const arbiters = [arbiter1.address, arbiter2.address];
                const arbitersRequired = 2;

                //escrow is created in contract with right values
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    false,
                    arbiters,
                    arbitersRequired
                );

                verifyEscrow(escrow, {
                    id: escrowId,
                    payer: payer1.address,
                    receiver: receiver1.address,
                    arbiters,
                    arbitersRequired: arbitersRequired,
                    amount,
                    currency: ethers.ZeroAddress,
                    amountPaid: 0,
                    amountRefunded: 0,
                    amountReleased: 0,
                    startTime: 0,
                    endTime: 0,
                    status: 0,
                    fullyPaid: false,
                    payerReleased: false,
                    receiverReleased: false,
                    released: false,
                });
            });
        });

        describe('Exceptions', function () {
            it('cannot create a new escrow with a duplicate id', async function () {
                const amount = 10000000;
                const isToken = false;

                //create escrows with duplicate payment ids
                const escrowId = ethers.keccak256('0x01');

                //create escrow
                await createEscrow(escrowId, payer1, receiver1.address, amount);

                //create the same escrow again
                await expect(
                    createEscrow(escrowId, payer1, receiver1.address, amount)
                ).to.be.revertedWith('DuplicateEscrow');
            });

            it('cannot create a new escrow with invalid amount', async function () {
                const amount = 0;
                const isToken = false;

                //create escrow
                const escrowId = ethers.keccak256('0x01');
                await expect(
                    createEscrow(escrowId, payer1, receiver1.address, amount)
                ).to.be.revertedWith('InvalidAmount');
            });

            it('cannot create a new escrow with invalid ERC20', async function () {
                const amount = 10000000;
                const isToken = false;

                //create escrow
                const escrowId = ethers.keccak256('0x01');

                await expect(
                    polyEscrow.connect(receiver1).createEscrow({
                        currency: '0x0000000000000000000000000000000000000013',
                        id: escrowId,
                        receiver: receiver1.address,
                        payer: payer1.address,
                        arbiters: [],
                        arbitersRequired: 0,
                        amount,
                        startTime: 0,
                        endTime: 0,
                        arbitrationModule: arbitrationModule.target,
                    })
                ).to.be.revertedWith('InvalidToken');
            });

            it('cannot create a new escrow with invalid payer address', async function () {
                const amount = 10000000;
                const isToken = false;

                //create escrow
                const escrowId = ethers.keccak256('0x01');

                await expect(
                    polyEscrow.connect(receiver1).createEscrow({
                        currency: ethers.ZeroAddress,
                        id: escrowId,
                        receiver: receiver1.address,
                        payer: ethers.ZeroAddress,
                        arbiters: [],
                        arbitersRequired: 0,
                        amount,
                        startTime: 0,
                        endTime: 0,
                        arbitrationModule: ethers.ZeroAddress,
                    })
                ).to.be.revertedWith('InvalidPayer');
            });

            it('cannot create a new escrow with invalid receiver address', async function () {
                const amount = 10000000;
                const isToken = false;

                //create escrow
                const escrowId = ethers.keccak256('0x01');

                await expect(
                    polyEscrow.connect(receiver1).createEscrow({
                        currency: ethers.ZeroAddress,
                        id: escrowId,
                        receiver: ethers.ZeroAddress,
                        payer: payer1.address,
                        arbiters: [],
                        arbitersRequired: 0,
                        amount,
                        startTime: 0,
                        endTime: 0,
                        arbitrationModule: ethers.ZeroAddress,
                    })
                ).to.be.revertedWith('InvalidReceiver');
            });

            it('cannot create a new escrow with more than the max number of arbiters', async function () {
                const amount = 10000000;
                const isToken = false;

                //create escrow
                const escrowId = ethers.keccak256('0x01');

                await expect(
                    polyEscrow.connect(receiver1).createEscrow({
                        currency: ethers.ZeroAddress,
                        id: escrowId,
                        receiver: receiver1.address,
                        payer: payer1.address,
                        arbiters: [
                            '0x0000000000000000000000000000000000000001',
                            '0x0000000000000000000000000000000000000002',
                            '0x0000000000000000000000000000000000000003',
                            '0x0000000000000000000000000000000000000004',
                            '0x0000000000000000000000000000000000000005',
                            '0x0000000000000000000000000000000000000006',
                            '0x0000000000000000000000000000000000000007',
                            '0x0000000000000000000000000000000000000008',
                            '0x0000000000000000000000000000000000000009',
                            '0x0000000000000000000000000000000000000010',
                            '0x0000000000000000000000000000000000000011',
                            '0x0000000000000000000000000000000000000012',
                        ],
                        arbitersRequired: 0,
                        amount,
                        startTime: 0,
                        endTime: 0,
                        arbitrationModule: ethers.ZeroAddress,
                    })
                ).to.be.revertedWith('MaxArbitersExceeded');
            });

            it('cannot create a new escrow with an invalid arbiter address', async function () {
                const amount = 10000000;
                const isToken = false;

                //create escrow
                const escrowId = ethers.keccak256('0x01');

                await expect(
                    polyEscrow.connect(receiver1).createEscrow({
                        currency: ethers.ZeroAddress,
                        id: escrowId,
                        receiver: receiver1.address,
                        payer: payer1.address,
                        arbiters: [
                            '0x0000000000000000000000000000000000000001',
                            '0x0000000000000000000000000000000000000002',
                            '0x0000000000000000000000000000000000000000',
                        ],
                        arbitersRequired: 0,
                        amount,
                        startTime: 0,
                        endTime: 0,
                        arbitrationModule: ethers.ZeroAddress,
                    })
                ).to.be.revertedWith('InvalidArbiter');
            });

            it('cannot create a new escrow with the payer as arbiter', async function () {
                const amount = 10000000;
                const isToken = false;

                //create escrow
                const escrowId = ethers.keccak256('0x01');

                await expect(
                    polyEscrow.connect(receiver1).createEscrow({
                        currency: ethers.ZeroAddress,
                        id: escrowId,
                        receiver: receiver1.address,
                        payer: payer1.address,
                        arbiters: [payer1.address],
                        arbitersRequired: 0,
                        amount,
                        startTime: 0,
                        endTime: 0,
                        arbitrationModule: ethers.ZeroAddress,
                    })
                ).to.be.revertedWith('InvalidArbiter');
            });

            it('cannot create a new escrow with the receiver as arbiter', async function () {
                const amount = 10000000;
                const isToken = false;

                //create escrow
                const escrowId = ethers.keccak256('0x01');

                await expect(
                    polyEscrow.connect(receiver1).createEscrow({
                        currency: ethers.ZeroAddress,
                        id: escrowId,
                        receiver: receiver1.address,
                        payer: payer1.address,
                        arbiters: [receiver1.address],
                        arbitersRequired: 0,
                        amount,
                        startTime: 0,
                        endTime: 0,
                        arbitrationModule: ethers.ZeroAddress,
                    })
                ).to.be.revertedWith('InvalidArbiter');
            });

            it('cannot create escrow where payer & receiver are the same', async function () {
                const amount = 10000000;
                const isToken = false;

                //create escrow
                const escrowId = ethers.keccak256('0x01');

                await expect(
                    polyEscrow.connect(receiver1).createEscrow({
                        currency: ethers.ZeroAddress,
                        id: escrowId,
                        receiver: receiver1.address,
                        payer: receiver1.address,
                        arbiters: [],
                        arbitersRequired: 0,
                        amount,
                        startTime: 0,
                        endTime: 0,
                        arbitrationModule: ethers.ZeroAddress,
                    })
                ).to.be.revertedWith('InvalidReceiver');
            });

            it.skip('cannot create escrow with more required arbiters than arbiters', async function () {});
        });

        describe('Events', function () {
            it('emits EscrowCreated', async function () {
                const amount = BigInt(10000000);
                const isToken = false;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');

                //escrow is logged in contract with right values
                await expect(
                    polyEscrow.connect(receiver1).createEscrow({
                        currency: ethers.ZeroAddress,
                        id: escrowId,
                        receiver: receiver1.address,
                        payer: payer1.address,
                        arbiters: [],
                        arbitersRequired: 0,
                        amount,
                        startTime: 0,
                        endTime: 0,
                        arbitrationModule: ethers.ZeroAddress,
                    })
                )
                    .to.emit(polyEscrow, 'EscrowCreated')
                    .withArgs(escrowId);
            });
        });
    });

    describe('Place Payments', function () {
        //TODO: verify appropriate escrow properties in each happy path case
        describe('Happy Paths', function () {
            async function testPlaceSinglePayment(isToken: boolean) {
                const initialContractBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );
                const initialPayerBalance = await getBalance(
                    payer1.address,
                    isToken
                );
                const amount = BigInt(10000000);

                //create escrow
                const escrowId = ethers.keccak256('0x01');
                let escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //place a payment
                escrow = await placePayment(escrowId, payer1, amount, isToken);

                expect(escrow.amountPaid).to.equal(amount);
                expect(escrow.fullyPaid).to.equal(true);

                const newContractBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );
                const newPayerBalance = await getBalance(
                    payer1.address,
                    isToken
                );

                expect(newContractBalance).to.equal(
                    initialContractBalance + amount
                );
                expect(newPayerBalance).to.be.lessThanOrEqual(
                    initialPayerBalance - amount
                );
            }

            it('can place a single native payment', async function () {
                await testPlaceSinglePayment(false);
            });

            it('can place a single token payment', async function () {
                await testPlaceSinglePayment(true);
            });

            it('paid token amounts accrue in contract', async function () {
                const amount1 = 10000000;
                const amount2 = 20000000;
                const amount3 = 30000000;
                const isToken = true;

                const escrowId1 = ethers.keccak256('0x01');
                const escrowId2 = ethers.keccak256('0x02');
                const escrowId3 = ethers.keccak256('0x03');

                //create escrows
                await createEscrow(
                    escrowId1,
                    payer1,
                    receiver1.address,
                    amount1,
                    isToken
                );
                await createEscrow(
                    escrowId2,
                    payer1,
                    receiver1.address,
                    amount2,
                    isToken
                );
                await createEscrow(
                    escrowId3,
                    payer2,
                    receiver1.address,
                    amount3,
                    isToken
                );

                //pass 2 payments
                await placePayment(escrowId1, payer1, amount1, isToken);
                await placePayment(escrowId2, payer1, amount2, isToken);

                //check balance accrual
                expect(await getBalance(polyEscrow.target, isToken)).to.equal(
                    amount1 + amount2
                );

                //pass another payment
                await placePayment(escrowId3, payer2, amount3, isToken);

                //check balance accrual
                expect(await getBalance(polyEscrow.target, isToken)).to.equal(
                    amount1 + amount2 + amount3
                );
            });

            it('paid native amounts accrue in contract', async function () {
                const amount1 = 10000000;
                const amount2 = 20000000;
                const amount3 = 30000000;
                const isToken = false;

                const escrowId1 = ethers.keccak256('0x01');
                const escrowId2 = ethers.keccak256('0x02');
                const escrowId3 = ethers.keccak256('0x03');

                //create escrows
                await createEscrow(
                    escrowId1,
                    payer1,
                    receiver1.address,
                    amount1,
                    isToken
                );
                await createEscrow(
                    escrowId2,
                    payer1,
                    receiver1.address,
                    amount2,
                    isToken
                );
                await createEscrow(
                    escrowId3,
                    payer2,
                    receiver1.address,
                    amount3,
                    isToken
                );

                //pass 2 payments
                await placePayment(escrowId1, payer1, amount1, isToken);
                await placePayment(escrowId2, payer1, amount2, isToken);

                //check balance accrual
                expect(await getBalance(polyEscrow.target, isToken)).to.equal(
                    amount1 + amount2
                );

                //pass another payment
                await placePayment(escrowId3, payer2, amount3, isToken);

                //check balance accrual
                expect(await getBalance(polyEscrow.target, isToken)).to.equal(
                    amount1 + amount2 + amount3
                );
            });
        });

        //TODO: verify appropriate escrow properties in each sad path case
        describe('Exceptions', function () {
            it('cannot place payment to nonexistent escrow', async function () {
                const amount = 10000000;
                const isToken = false;

                //create escrow
                const escrowId = ethers.keccak256('0x01');

                await expect(
                    polyEscrow.connect(payer1).placePayment(
                        {
                            escrowId: escrowId,
                            currency: ethers.ZeroAddress,
                            amount,
                        },
                        { value: amount - 1 }
                    )
                ).to.be.revertedWith('InvalidEscrow');
            });

            it('cannot place payment without correct native amount', async function () {
                const amount = 10000000;
                const isToken = false;

                //place the payment with less than required amount
                const escrowId = ethers.keccak256('0x01');

                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                await expect(
                    polyEscrow.connect(payer1).placePayment(
                        {
                            escrowId: escrowId,
                            currency: ethers.ZeroAddress,
                            amount,
                        },
                        { value: amount - 1 }
                    )
                ).to.be.revertedWith('InvalidAmount');
            });

            it('cannot place payment without correct token amount approved', async function () {
                const amount = 10000000;
                const isToken = true;

                //place the payment with less than required amount
                const escrowId = ethers.keccak256('0x01');

                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                await testToken
                    .connect(payer1)
                    .approve(polyEscrow.target, amount - 1);
                await expect(
                    polyEscrow.connect(payer1).placePayment({
                        escrowId: escrowId,
                        currency: testToken.target,
                        amount,
                    })
                ).to.be.reverted;
            });

            it('cannot place payment without correct token amount in balance', async function () {
                const amount = 10000000;
                const isToken = true;

                //give all tokens away
                await testToken
                    .connect(payer1)
                    .transfer(
                        payer2.address,
                        await getBalance(payer1.address, true)
                    );

                //place the payment with less than required amount
                const escrowId = ethers.keccak256('0x01');

                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                await testToken
                    .connect(payer1)
                    .approve(polyEscrow.target, amount);
                await expect(
                    polyEscrow.connect(payer1).placePayment({
                        escrowId: escrowId,
                        currency: testToken.target,
                        amount,
                    })
                ).to.be.reverted;
            });

            it('cannot place payment with the wrong currency', async function () {
                const amount = 10000000;
                const isToken = true;
                const invalidTokenCurrency =
                    '0x0000000000000000000000000000000000000022';

                //create the escrow for token
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //place the payment with less than required amount
                await expect(
                    polyEscrow.connect(payer1).placePayment({
                        escrowId: escrowId,
                        currency: invalidTokenCurrency,
                        amount,
                    })
                ).to.be.revertedWith('InvalidCurrency');
            });

            it('cannot place payment if payer and receiver are the same', async function () {
                const amount = 10000000;
                const isToken = true;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await expect(
                    createEscrow(
                        escrowId,
                        payer1,
                        payer1.address,
                        amount,
                        isToken
                    )
                ).to.revertedWith('InvalidReceiver');
            });

            it.skip('cannot place payment if escrow is already released', async function () {});

            it.skip('cannot place payment if escrow is in arbitration', async function () {});

            it.skip('cannot place payment if escrow is not yet active', async function () {});

            it.skip('failed token payment', async function () {});
        });

        describe('Events', function () {
            async function testEmitsEscrowFullyPaid(isToken: boolean) {
                const amount = BigInt(10000000);

                //create escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //place a payment
                if (isToken) {
                    await testToken
                        .connect(payer1)
                        .approve(polyEscrow.target, amount);
                    await expect(
                        polyEscrow.connect(payer1).placePayment({
                            escrowId: escrowId,
                            currency: testToken.target,
                            amount,
                        })
                    )
                        .to.emit(polyEscrow, 'EscrowFullyPaid')
                        .withArgs(escrowId, amount);
                } else {
                    await expect(
                        polyEscrow.connect(payer1).placePayment(
                            {
                                escrowId: escrowId,
                                currency: ethers.ZeroAddress,
                                amount,
                            },
                            isToken ? undefined : { value: amount }
                        )
                    )
                        .to.emit(polyEscrow, 'EscrowFullyPaid')
                        .withArgs(escrowId, amount);
                }
            }

            async function testDoesNotEmitEscrowFullyPaid(isToken: boolean) {
                const amount = BigInt(10000000);

                //create escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //place a payment
                const partialAmount = amount - BigInt(1);
                if (isToken) {
                    await testToken
                        .connect(payer1)
                        .approve(polyEscrow.target, partialAmount);
                    await expect(
                        polyEscrow.connect(payer1).placePayment({
                            escrowId: escrowId,
                            currency: testToken.target,
                            amount: partialAmount,
                        })
                    ).to.not.emit(polyEscrow, 'EscrowFullyPaid');
                } else {
                    await expect(
                        polyEscrow.connect(payer1).placePayment(
                            {
                                escrowId: escrowId,
                                currency: ethers.ZeroAddress,
                                amount: partialAmount,
                            },
                            { value: partialAmount }
                        )
                    ).to.not.emit(polyEscrow, 'EscrowFullyPaid');
                }
            }

            async function testEmitsPaymentReceived(isToken: boolean) {
                const amount = BigInt(10000000);
                const partialAmount = amount / BigInt(2);

                //create escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //place a payment
                if (isToken) {
                    await testToken
                        .connect(payer1)
                        .approve(polyEscrow.target, partialAmount);
                    await expect(
                        polyEscrow.connect(payer1).placePayment({
                            escrowId: escrowId,
                            currency: testToken.target,
                            amount: partialAmount,
                        })
                    )
                        .to.emit(polyEscrow, 'PaymentReceived')
                        .withArgs(escrowId, payer1.address, partialAmount);
                } else {
                    await expect(
                        polyEscrow.connect(payer1).placePayment(
                            {
                                escrowId: escrowId,
                                currency: ethers.ZeroAddress,
                                amount: partialAmount,
                            },
                            { value: partialAmount }
                        )
                    )
                        .to.emit(polyEscrow, 'PaymentReceived')
                        .withArgs(escrowId, payer1.address, partialAmount);
                }
            }

            async function testEmitsPaymentReceivedAndEscrowFullyPaid(
                isToken: boolean
            ) {
                const amount = BigInt(10000000);
                const partialAmount = amount / BigInt(2);

                //create escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //place a payment
                if (isToken) {
                    await testToken
                        .connect(payer1)
                        .approve(polyEscrow.target, partialAmount);
                    await expect(
                        polyEscrow.connect(payer1).placePayment({
                            escrowId: escrowId,
                            currency: testToken.target,
                            amount: partialAmount,
                        })
                    )
                        .to.emit(polyEscrow, 'PaymentReceived')
                        .withArgs(escrowId, payer1.address, partialAmount);

                    //place the remaining payment
                    await testToken
                        .connect(payer1)
                        .approve(polyEscrow.target, amount);
                    await expect(
                        polyEscrow.connect(payer1).placePayment({
                            escrowId: escrowId,
                            currency: testToken.target,
                            amount: partialAmount,
                        })
                    )
                        .to.emit(polyEscrow, 'EscrowFullyPaid')
                        .withArgs(escrowId, amount);
                } else {
                    await expect(
                        polyEscrow.connect(payer1).placePayment(
                            {
                                escrowId: escrowId,
                                currency: ethers.ZeroAddress,
                                amount: partialAmount,
                            },
                            { value: partialAmount }
                        )
                    )
                        .to.emit(polyEscrow, 'PaymentReceived')
                        .withArgs(escrowId, payer1.address, partialAmount);

                    //place the remaining payment
                    await expect(
                        polyEscrow.connect(payer1).placePayment(
                            {
                                escrowId: escrowId,
                                currency: ethers.ZeroAddress,
                                amount: partialAmount,
                            },
                            { value: partialAmount }
                        )
                    )
                        .to.emit(polyEscrow, 'EscrowFullyPaid')
                        .withArgs(escrowId, amount);
                }
            }

            it('emits EscrowFullyPaid for native payment', async function () {
                await testEmitsEscrowFullyPaid(false);
            });

            it('emits EscrowFullyPaid for token payment', async function () {
                await testEmitsEscrowFullyPaid(true);
            });

            it('does not emit EscrowFullyPaid for partial native payment', async function () {
                await testDoesNotEmitEscrowFullyPaid(false);
            });

            it('does not emit EscrowFullyPaid for partial token payment', async function () {
                await testDoesNotEmitEscrowFullyPaid(true);
            });

            it('emits PaymentReceived for partial native payment', async function () {
                await testEmitsPaymentReceived(false);
            });

            it('emits PaymentReceived for partial token payment', async function () {
                await testEmitsPaymentReceived(true);
            });

            it('emits PaymentReceived and EscrowFullyPaid for token payment', async function () {
                await testEmitsPaymentReceivedAndEscrowFullyPaid(false);
            });

            it('emits PaymentReceived and EscrowFullyPaid for token payment', async function () {
                await testEmitsPaymentReceivedAndEscrowFullyPaid(true);
            });
        });
    });

    describe('Release Escrows', function () {
        describe('Happy Paths', function () {
            async function testCanReleaseWithApprovals(isToken: boolean) {
                const initialContractBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );
                const initialReceiverBalance = await getBalance(
                    receiver1.address,
                    isToken
                );
                const amount = 10000000;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //fully pay the escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //check the balance
                const newContractBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );
                const newReceiverBalance = await getBalance(
                    receiver1.address,
                    isToken
                );
                expect(newContractBalance).to.equal(
                    initialContractBalance + BigInt(amount)
                );
                expect(newReceiverBalance).to.equal(initialReceiverBalance);

                //try to release the payment
                await polyEscrow.connect(receiver1).releaseEscrow(escrowId);
                await polyEscrow.connect(payer1).releaseEscrow(escrowId);

                //ensure that payment has been released
                const payment = convertEscrow(
                    await polyEscrow.getEscrow(escrowId)
                );
                verifyEscrow(payment, {
                    id: escrowId,
                    payer: payer1.address,
                    receiver: receiver1.address,
                    amount,
                    amountRefunded: 0,
                    amountPaid: amount,
                    amountReleased: amount,
                    payerReleased: true,
                    receiverReleased: true,
                    released: true,
                    currency: isToken ? testToken.target : ethers.ZeroAddress,
                });

                //check the balance
                const finalContractBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );
                const finalReceiverBalance = await getBalance(
                    receiver1.address,
                    isToken
                );

                expect(finalContractBalance).to.equal(
                    newContractBalance - BigInt(amount)
                );
                expect(finalReceiverBalance).to.be.lessThanOrEqual(
                    newReceiverBalance + BigInt(amount)
                );
            }

            it('can release a native payment with both approvals', async function () {
                await testCanReleaseWithApprovals(false);
            });

            it('can release a token payment with both approvals', async function () {
                await testCanReleaseWithApprovals(true);
            });
        });

        describe('Exceptions', function () {
            it('cannot release a payment with no approvals', async function () {
                const initialContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const amount = 10000000;
                const isToken = true;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //fully pay the escrow
                await placePayment(escrowId, payer1, amount, true);

                //check the balance
                const newContractBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );
                expect(newContractBalance).to.equal(
                    initialContractBalance + BigInt(amount)
                );

                //try to release the payment
                await expect(
                    polyEscrow.connect(arbiter1).releaseEscrow(escrowId)
                ).to.be.revertedWith('Unauthorized');
            });

            it('cannot release a payment with only payer approval', async function () {
                const initialContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const amount = 10000000;
                const isToken = true;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //fully pay the escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //check the balance
                const newContractBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );
                expect(newContractBalance).to.equal(
                    initialContractBalance + BigInt(amount)
                );

                //try to release the payment
                await polyEscrow.connect(payer1).releaseEscrow(escrowId);

                //ensure that nothing has been released
                const payment = convertEscrow(
                    await polyEscrow.getEscrow(escrowId)
                );
                verifyEscrow(payment, {
                    id: escrowId,
                    payer: payer1.address,
                    receiver: receiver1.address,
                    amount,
                    amountRefunded: 0,
                    payerReleased: true,
                    receiverReleased: false,
                    released: false,
                    currency: testToken.target,
                });

                //check the balance
                const finalContractBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );
                expect(finalContractBalance).to.equal(newContractBalance);
            });

            it('cannot release a payment with only receiver approval', async function () {
                const initialContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const amount = 10000000;
                const isToken = true;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //fully pay the escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //check the balance
                const newContractBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );
                expect(newContractBalance).to.equal(
                    initialContractBalance + BigInt(amount)
                );

                //try to release the payment
                await polyEscrow.connect(receiver1).releaseEscrow(escrowId);

                //ensure that nothing has been released
                const payment = convertEscrow(
                    await polyEscrow.getEscrow(escrowId)
                );
                verifyEscrow(payment, {
                    id: escrowId,
                    payer: payer1.address,
                    receiver: receiver1.address,
                    amount,
                    amountRefunded: 0,
                    payerReleased: false,
                    receiverReleased: true,
                    released: false,
                    currency: testToken.target,
                });

                //check the balance
                const finalContractBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );
                expect(finalContractBalance).to.equal(newContractBalance);
            });

            it('not possible to release a payment for which one is not a party', async function () {
                const initialContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const amount = 10000000;
                const isToken = true;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //fully pay the escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //check the balance
                const newContractBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );
                expect(newContractBalance).to.equal(
                    initialContractBalance + BigInt(amount)
                );

                //try to release the payment, but with an unauthorized account
                await expect(
                    polyEscrow.connect(nonOwner).releaseEscrow(escrowId)
                ).to.be.revertedWith('Unauthorized');

                //ensure that nothing has been released
                const payment = convertEscrow(
                    await polyEscrow.getEscrow(escrowId)
                );
                verifyEscrow(payment, {
                    id: escrowId,
                    payer: payer1.address,
                    receiver: receiver1.address,
                    amount,
                    amountRefunded: 0,
                    payerReleased: false,
                    receiverReleased: false,
                    released: false,
                    currency: testToken.target,
                });

                //check the balance
                const finalContractBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );
                expect(finalContractBalance).to.equal(newContractBalance);
            });

            it('not possible to release a payment twice', async function () {
                const isToken = true;
                const initialContractBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );
                const initialReceiverBalance = await getBalance(
                    receiver1.address,
                    isToken
                );
                const amount = 10000000;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //fully pay the escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //check the balance
                const newContractBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );
                const newReceiverBalance = await getBalance(
                    receiver1.address,
                    isToken
                );
                expect(newContractBalance).to.equal(
                    initialContractBalance + BigInt(amount)
                );
                expect(newReceiverBalance).to.equal(initialReceiverBalance);

                //try to release the payment
                await polyEscrow.connect(receiver1).releaseEscrow(escrowId);
                await polyEscrow.connect(payer1).releaseEscrow(escrowId);

                //ensure that it has been released
                const payment = convertEscrow(
                    await polyEscrow.getEscrow(escrowId)
                );
                verifyEscrow(payment, {
                    id: escrowId,
                    payer: payer1.address,
                    receiver: receiver1.address,
                    amount,
                    amountRefunded: 0,
                    payerReleased: true,
                    receiverReleased: true,
                    released: true,
                    currency: testToken.target,
                });

                //try to release the payment a second time
                await expect(
                    polyEscrow.connect(receiver1).releaseEscrow(escrowId)
                ).to.be.revertedWith('AlreadyReleased');
                await expect(
                    polyEscrow.connect(payer1).releaseEscrow(escrowId)
                ).to.be.revertedWith('AlreadyReleased');
            });
        });

        describe.skip('Events', function () {});
    });

    describe('Refund Payments', function () {
        async function refundTest(
            amount: number,
            refundAmount: number,
            payerAccount: HardhatEthersSigner,
            receiverAccount: HardhatEthersSigner,
            refunderAccount: HardhatEthersSigner,
            isToken: boolean = false
        ): Promise<string> {
            const initialContractBalance = await getBalance(
                polyEscrow.target,
                isToken
            );
            const initialPayerBalance = await getBalance(
                payerAccount.address,
                isToken
            );

            //create the escrow
            const escrowId = ethers.keccak256('0x01');
            await createEscrow(
                escrowId,
                payerAccount,
                receiverAccount.address,
                amount,
                isToken,
                [arbiter1.address],
                0
            );

            //fully pay the escrow
            await placePayment(escrowId, payer1, amount, isToken);

            //partially refund the payment
            await polyEscrow
                .connect(refunderAccount)
                .refundPayment(escrowId, refundAmount);

            //get & check the payment - was it refunded?
            const payment = convertEscrow(await polyEscrow.getEscrow(escrowId));
            expect(payment.amountRefunded).to.equal(refundAmount);
            expect(payment.amount).to.equal(amount);

            //check the balances
            const finalContractBalance = await getBalance(
                polyEscrow.target,
                isToken
            );
            const finalPayerBalance = await getBalance(
                payerAccount.address,
                isToken
            );

            expect(finalContractBalance).to.equal(
                initialContractBalance + BigInt(amount - refundAmount)
            );
            expect(finalPayerBalance).to.be.lessThanOrEqual(
                initialPayerBalance - BigInt(amount - refundAmount)
            );

            return escrowId;
        }

        describe('Happy Paths', function () {
            async function testCanDoMultiplePartials(isToken: boolean) {
                const amount = 1000000;
                const refundAmount = amount / 5;
                const initialContractBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );
                const initialPayerBalance = await getBalance(
                    payer1.address,
                    isToken
                );

                //initial refund
                const escrowId = await refundTest(
                    amount,
                    refundAmount,
                    payer1,
                    receiver1,
                    receiver1,
                    isToken
                );

                //partially refund the payment
                await polyEscrow
                    .connect(receiver1)
                    .refundPayment(escrowId, refundAmount);

                //get & check the payment - was it refunded?
                const payment = convertEscrow(
                    await polyEscrow.getEscrow(escrowId)
                );
                expect(payment.amountRefunded).to.equal(refundAmount * 2);
                expect(payment.amount).to.equal(amount);

                //check the balances
                const finalContractBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );
                const finalPayerBalance = await getBalance(
                    payer1.address,
                    isToken
                );

                expect(finalContractBalance).to.equal(
                    initialContractBalance + BigInt(amount - refundAmount * 2)
                );
                expect(finalPayerBalance).to.be.lessThanOrEqual(
                    initialPayerBalance - BigInt(amount - refundAmount * 2)
                );
            }

            it('receiver can cause a partial refund of native', async function () {
                const amount = 1000000000;
                const isToken = false;
                await refundTest(
                    amount,
                    amount / 5,
                    payer1,
                    receiver1,
                    receiver1,
                    isToken
                );
            });

            it('receiver can cause a partial refund of token', async function () {
                const amount = 1000000;
                const isToken = true;
                await refundTest(
                    amount,
                    amount / 5,
                    payer1,
                    receiver1,
                    receiver1,
                    isToken
                );
            });

            it('receiver can cause a full refund of native', async function () {
                const amount = 1000000000;
                const isToken = false;
                await refundTest(
                    amount,
                    amount,
                    payer1,
                    receiver1,
                    receiver1,
                    isToken
                );
            });

            it('receiver can cause a full refund of token', async function () {
                const amount = 1000000;
                const isToken = true;
                await refundTest(
                    amount,
                    amount,
                    payer1,
                    receiver1,
                    receiver1,
                    isToken
                );
            });

            it('can do multiple partial refunds of native', async function () {
                await testCanDoMultiplePartials(false);
            });

            it('can do multiple partial refunds of token', async function () {
                await testCanDoMultiplePartials(true);
            });
        });

        describe('Exceptions', function () {
            it('not possible to refund a payment to which one is not a party', async function () {
                const amount = 100000000;
                const isToken = false;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [arbiter1.address]
                );

                //fully pay the escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //attempt to refund non-authorized
                await expect(
                    polyEscrow.connect(payer1).refundPayment(escrowId, amount)
                ).to.be.revertedWith('Unauthorized');

                //attempt to refund non-authorized
                await expect(
                    polyEscrow.connect(payer2).refundPayment(escrowId, amount)
                ).to.be.revertedWith('Unauthorized');

                //attempt to refund authorized
                await expect(
                    polyEscrow
                        .connect(receiver1)
                        .refundPayment(escrowId, amount)
                ).to.not.be.reverted;
            });

            it('not possible to refund more than the payment amount', async function () {
                const amount = 100000000;
                const isToken = true;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //pay into the escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //attempt to refund more than one should
                await expect(
                    polyEscrow
                        .connect(receiver1)
                        .refundPayment(escrowId, amount + 1)
                ).to.be.revertedWith('AmountExceeded');

                //attempt to refund normal amount
                await expect(
                    polyEscrow
                        .connect(receiver1)
                        .refundPayment(escrowId, amount)
                ).to.not.be.reverted;
            });

            it('not possible to refund more than the payment amount, using multiple refunds', async function () {
                const amount = 100000000;
                const isToken = true;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //pay into the escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //refunds that should be allowed
                await expect(
                    polyEscrow
                        .connect(receiver1)
                        .refundPayment(escrowId, amount - 2)
                ).to.not.be.reverted;
                await expect(
                    polyEscrow.connect(receiver1).refundPayment(escrowId, 1)
                ).to.not.be.reverted;

                //attempt to refund more than one should
                await expect(
                    polyEscrow.connect(receiver1).refundPayment(escrowId, 100)
                ).to.be.revertedWith('AmountExceeded');

                //attempt to refund normal amount
                await expect(
                    polyEscrow.connect(receiver1).refundPayment(escrowId, 1)
                ).to.not.be.reverted;
            });
        });

        describe('Events', function () {});
    });

    describe('Fee Amounts', function () {
        this.beforeEach(async () => {});

        describe('Happy Paths', function () {
            it('fees are calculated correctly', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = true;
                const receiverInitialAmount = await getBalance(
                    receiver1.address,
                    isToken
                );

                //set fee bps
                await systemSettings.setFeeBps(120);

                //ensure that dao balance at start is 0
                expect(await getBalance(vaultAddress, isToken)).to.equal(0);

                //place a payment
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //pay into the escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //release the payment from escrow
                await polyEscrow.connect(payer1).releaseEscrow(escrowId);
                await polyEscrow.connect(receiver1).releaseEscrow(escrowId);

                //fee should be in the vault
                const feeBps = parseInt(await systemSettings.feeBps());
                const feeAmount = amount * (feeBps / 10000);
                expect(await getBalance(vaultAddress, isToken)).to.equal(
                    feeAmount
                );

                //remainder amount should have gone to the receiver
                expect(await getBalance(receiver1.address, isToken)).to.equal(
                    receiverInitialAmount + BigInt(amount - feeAmount)
                );
            });

            it('fee can be 0%', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = true;
                const receiverInitialAmount = await getBalance(
                    receiver1.address,
                    isToken
                );

                await systemSettings.setFeeBps(0);

                //ensure that dao balance at start is 0
                expect(await getBalance(vaultAddress, isToken)).to.equal(0);

                //place a payment
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
                );

                //pay into the escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //release the payment from escrow
                await polyEscrow.connect(payer1).releaseEscrow(escrowId);
                await polyEscrow.connect(receiver1).releaseEscrow(escrowId);

                //no fees should have gone to the vault
                expect(await getBalance(vaultAddress, isToken)).to.equal(0);

                //full amount should have gone to the receiver
                expect(await getBalance(receiver1.address, isToken)).to.equal(
                    receiverInitialAmount + BigInt(amount)
                );
            });

            it('fee is calculated from amount remaining after refund', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = true;
                const refundAmount = 40000;
                const receiverInitialAmount = await getBalance(
                    receiver1.address,
                    isToken
                );

                //set fee bps
                await systemSettings.setFeeBps(120);

                //ensure that dao balance at start is 0
                expect(await getBalance(vaultAddress, isToken)).to.equal(0);

                //place a payment
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //pay into the escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //refund a small amount
                await polyEscrow
                    .connect(receiver1)
                    .refundPayment(escrowId, refundAmount);

                //release the payment from escrow
                await polyEscrow.connect(payer1).releaseEscrow(escrowId);
                await polyEscrow.connect(receiver1).releaseEscrow(escrowId);

                //fee should be in the vault
                const feeBps = parseInt(await systemSettings.feeBps());
                const feeAmount = (amount - refundAmount) * (feeBps / 10000);
                expect(await getBalance(vaultAddress, isToken)).to.equal(
                    (amount - refundAmount) * (feeBps / 10000)
                );

                //remainder should have gone to receiver
                expect(await getBalance(receiver1.address, isToken)).to.equal(
                    receiverInitialAmount +
                        BigInt(amount - refundAmount - feeAmount)
                );
            });

            it('no fee is taken from fully refunded payment', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = true;
                const refundAmount = amount;
                const receiverInitialAmount = await getBalance(
                    receiver1.address,
                    isToken
                );

                //set fee bps
                await systemSettings.setFeeBps(120);

                //ensure that dao balance at start is 0
                expect(await getBalance(vaultAddress, isToken)).to.equal(0);

                //place a payment
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //pay into the escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //refund all
                await polyEscrow
                    .connect(receiver1)
                    .refundPayment(escrowId, refundAmount);

                //release the payment from escrow
                await polyEscrow.connect(payer1).releaseEscrow(escrowId);
                await polyEscrow.connect(receiver1).releaseEscrow(escrowId);

                //no fee should be in the vault
                expect(await getBalance(vaultAddress, isToken)).to.equal(0);

                //none should have gone to receiver
                expect(await getBalance(receiver1.address, isToken)).to.equal(
                    receiverInitialAmount
                );
            });

            it('fee stays the same even if systemSettings is changed', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = true;
                const receiverInitialAmount = await getBalance(
                    receiver1.address,
                    isToken
                );

                //set fee bps to 120
                const initialFeeBps = 120;
                await systemSettings.setFeeBps(initialFeeBps);

                //ensure that dao balance at start is 0
                expect(await getBalance(vaultAddress, isToken)).to.equal(0);

                //place a payment
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //now change the system fee bps to a much higher value
                await systemSettings.setFeeBps(500);

                //pay into the escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //release the payment from escrow
                await polyEscrow.connect(payer1).releaseEscrow(escrowId);
                await polyEscrow.connect(receiver1).releaseEscrow(escrowId);

                //fee should be in the vault
                const feeAmount = amount * (initialFeeBps / 10000);
                expect(await getBalance(vaultAddress, isToken)).to.equal(
                    feeAmount
                );

                //remainder amount should have gone to the receiver
                expect(await getBalance(receiver1.address, isToken)).to.equal(
                    receiverInitialAmount + BigInt(amount - feeAmount)
                );
            });
        });

        describe('Exceptions', function () {});

        describe('Events', function () {});
    });

    describe('Start and End Dates', function () {
        it('can set start and end dates', async function () {
            const escrowId = ethers.keccak256('0x01');
            const amount = 10000000;
            const isToken = true;

            const currentTime = await time.latest();
            const startTime = currentTime - ONE_HOUR;
            const endTime = currentTime + ONE_DAY;

            //place a payment
            await createEscrow(
                escrowId,
                payer1,
                receiver1.address,
                amount,
                isToken,
                [arbiter1.address, arbiter2.address],
                1,
                startTime,
                endTime
            );

            const escrow = await getEscrow(escrowId);

            expect(escrow.startTime).to.equal(startTime);
            expect(escrow.endTime).to.equal(endTime);
        });

        describe('Escrows will not operate before the prescribed start date', function () {
            it('escrow will not accept payment before the prescribed start date', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = false;

                const currentTime = await time.latest();
                const startTime = currentTime + ONE_HOUR;
                const endTime = currentTime + ONE_DAY;

                //create escrow
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [arbiter1.address, arbiter2.address],
                    1,
                    startTime,
                    endTime
                );

                expect(escrow.startTime).to.equal(startTime);
                expect(escrow.endTime).to.equal(endTime);

                await expect(
                    polyEscrow.connect(payer1).placePayment(
                        {
                            escrowId: escrowId,
                            currency: ethers.ZeroAddress,
                            amount,
                        },
                        { value: amount }
                    )
                ).to.be.revertedWith('EscrowNotActive');
            });

            it('escrow will not allow refunds before the prescribed start date', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = false;

                const currentTime = await time.latest();
                const startTime = currentTime + ONE_HOUR;
                const endTime = currentTime + ONE_DAY;

                //create escrow
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [arbiter1.address, arbiter2.address],
                    1,
                    startTime,
                    endTime
                );

                expect(escrow.startTime).to.equal(startTime);
                expect(escrow.endTime).to.equal(endTime);

                await expect(
                    polyEscrow.connect(receiver1).refundPayment(escrowId, 1)
                ).to.be.revertedWith('EscrowNotActive');
            });

            it('escrow will not allow release before the prescribed start date', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = false;

                const currentTime = await time.latest();
                const startTime = currentTime + ONE_HOUR;
                const endTime = currentTime + ONE_DAY;

                //create escrow
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [arbiter1.address, arbiter2.address],
                    1,
                    startTime,
                    endTime
                );

                expect(escrow.startTime).to.equal(startTime);
                expect(escrow.endTime).to.equal(endTime);

                await expect(
                    polyEscrow.connect(receiver1).releaseEscrow(escrowId)
                ).to.be.revertedWith('EscrowNotActive');
            });

            it('escrow will accept payment after the prescribed start date', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = false;

                const currentTime = await time.latest();
                const startTime = currentTime - ONE_HOUR;
                const endTime = currentTime + ONE_DAY;

                //create escrow
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [arbiter1.address, arbiter2.address],
                    1,
                    startTime,
                    endTime
                );

                expect(escrow.startTime).to.equal(startTime);
                expect(escrow.endTime).to.equal(endTime);

                await expect(
                    polyEscrow.connect(payer1).placePayment(
                        {
                            escrowId: escrowId,
                            currency: ethers.ZeroAddress,
                            amount,
                        },
                        { value: amount }
                    )
                ).to.not.be.reverted;
            });

            it('escrow will allow refunds after the prescribed start date', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = false;

                const currentTime = await time.latest();
                const startTime = currentTime - ONE_HOUR;
                const endTime = currentTime + ONE_DAY;

                //create escrow
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [arbiter1.address, arbiter2.address],
                    1,
                    startTime,
                    endTime
                );

                expect(escrow.startTime).to.equal(startTime);
                expect(escrow.endTime).to.equal(endTime);

                await expect(
                    polyEscrow.connect(receiver1).refundPayment(escrowId, 1)
                ).to.be.revertedWith('AmountExceeded');
            });

            it('escrow will allow release after the prescribed start date', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = false;

                const currentTime = await time.latest();
                const startTime = currentTime - ONE_HOUR;
                const endTime = currentTime + ONE_DAY;

                //create escrow
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [arbiter1.address, arbiter2.address],
                    1,
                    startTime,
                    endTime
                );

                expect(escrow.startTime).to.equal(startTime);
                expect(escrow.endTime).to.equal(endTime);

                await expect(
                    polyEscrow.connect(receiver1).releaseEscrow(escrowId)
                ).to.not.be.reverted;
            });
        });

        describe('Escrows will not operate after the prescribed end date', function () {
            it('escrow will not accept payment after the prescribed end date', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = false;

                const currentTime = await time.latest();
                const startTime = currentTime - ONE_HOUR;
                const endTime = currentTime + ONE_DAY;

                //create escrow
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [arbiter1.address, arbiter2.address],
                    1,
                    startTime,
                    endTime
                );

                expect(escrow.startTime).to.equal(startTime);
                expect(escrow.endTime).to.equal(endTime);

                await time.increase(ONE_DAY * 2);

                await expect(
                    polyEscrow.connect(payer1).placePayment(
                        {
                            escrowId: escrowId,
                            currency: ethers.ZeroAddress,
                            amount,
                        },
                        { value: amount }
                    )
                ).to.be.revertedWith('EscrowNotActive');
            });

            it('escrow will not allow refunds after the prescribed end date', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = false;

                const currentTime = await time.latest();
                const startTime = currentTime - ONE_HOUR;
                const endTime = currentTime + ONE_DAY;

                //create escrow
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [arbiter1.address, arbiter2.address],
                    1,
                    startTime,
                    endTime
                );

                expect(escrow.startTime).to.equal(startTime);
                expect(escrow.endTime).to.equal(endTime);

                await time.increase(ONE_DAY * 2);

                await expect(
                    polyEscrow.connect(receiver1).refundPayment(escrowId, 1)
                ).to.be.revertedWith('EscrowNotActive');
            });

            it('escrow will not allow release after the prescribed end date', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = false;

                const currentTime = await time.latest();
                const startTime = currentTime - ONE_HOUR;
                const endTime = currentTime + ONE_DAY;

                //create escrow
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [arbiter1.address, arbiter2.address],
                    1,
                    startTime,
                    endTime
                );

                expect(escrow.startTime).to.equal(startTime);
                expect(escrow.endTime).to.equal(endTime);

                await time.increase(ONE_DAY * 2);

                await expect(
                    polyEscrow.connect(receiver1).releaseEscrow(escrowId)
                ).to.be.revertedWith('EscrowNotActive');
            });

            it('escrow will accept payment before the prescribed end date', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = false;

                const currentTime = await time.latest();
                const startTime = currentTime - ONE_HOUR;
                const endTime = currentTime + ONE_DAY;

                //create escrow
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [arbiter1.address, arbiter2.address],
                    1,
                    startTime,
                    endTime
                );

                expect(escrow.startTime).to.equal(startTime);
                expect(escrow.endTime).to.equal(endTime);

                await expect(
                    polyEscrow.connect(payer1).placePayment(
                        {
                            escrowId: escrowId,
                            currency: ethers.ZeroAddress,
                            amount,
                        },
                        { value: amount }
                    )
                ).to.not.be.reverted;
            });

            it('escrow will allow refunds before the prescribed end date', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = false;

                const currentTime = await time.latest();
                const startTime = currentTime - ONE_HOUR;
                const endTime = currentTime + ONE_DAY;

                //create escrow
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [arbiter1.address, arbiter2.address],
                    1,
                    startTime,
                    endTime
                );

                expect(escrow.startTime).to.equal(startTime);
                expect(escrow.endTime).to.equal(endTime);

                await expect(
                    polyEscrow.connect(receiver1).refundPayment(escrowId, 1)
                ).to.be.revertedWith('AmountExceeded');
            });

            it('escrow will allow release before the prescribed end date', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = false;

                const currentTime = await time.latest();
                const startTime = currentTime - ONE_HOUR;
                const endTime = currentTime + ONE_DAY;

                //create escrow
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [arbiter1.address, arbiter2.address],
                    1,
                    startTime,
                    endTime
                );

                expect(escrow.startTime).to.equal(startTime);
                expect(escrow.endTime).to.equal(endTime);

                await expect(
                    polyEscrow.connect(receiver1).releaseEscrow(escrowId)
                ).to.not.be.reverted;
            });
        });

        describe('Exceptions', function () {
            it('cannot create escrow with an end date that is in the past', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = false;

                const currentTime = await time.latest();
                const startTime = currentTime - ONE_HOUR * 2;
                const endTime = currentTime - ONE_HOUR;

                //create escrow
                await expect(
                    polyEscrow.connect(payer1).createEscrow({
                        currency: isToken
                            ? testToken.target
                            : ethers.ZeroAddress,
                        id: escrowId,
                        receiver: receiver1,
                        payer: payer1.address,
                        arbiters: [],
                        arbitersRequired: 0,
                        amount,
                        startTime,
                        endTime,
                        arbitrationModule: ethers.ZeroAddress,
                    })
                ).to.be.revertedWith('InvalidEndDate');
            });

            it('cannot create escrow with an end date that is less than start date', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = false;

                const currentTime = await time.latest();
                const startTime = currentTime + ONE_DAY * 2;
                const endTime = currentTime + ONE_DAY;

                //create escrow
                await expect(
                    polyEscrow.connect(payer1).createEscrow({
                        currency: isToken
                            ? testToken.target
                            : ethers.ZeroAddress,
                        id: escrowId,
                        receiver: receiver1,
                        payer: payer1.address,
                        arbiters: [],
                        arbitersRequired: 0,
                        amount,
                        startTime,
                        endTime,
                        arbitrationModule: ethers.ZeroAddress,
                    })
                ).to.be.revertedWith('InvalidEndDate');
            });

            it('cannot create escrow with an end date that is too soon', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const isToken = false;

                const currentTime = await time.latest();
                const startTime = currentTime - ONE_HOUR;
                const endTime = currentTime + ONE_HOUR;

                //create escrow
                await expect(
                    polyEscrow.connect(payer1).createEscrow({
                        currency: isToken
                            ? testToken.target
                            : ethers.ZeroAddress,
                        id: escrowId,
                        receiver: receiver1,
                        payer: payer1.address,
                        arbiters: [],
                        arbitersRequired: 0,
                        amount,
                        startTime,
                        endTime,
                        arbitrationModule: ethers.ZeroAddress,
                    })
                ).to.be.revertedWith('InvalidEndDate');
            });
        });

        //TODO: test that arbitration still works outside of start & end dates
    });

    describe('Edge Cases', function () {});
});
