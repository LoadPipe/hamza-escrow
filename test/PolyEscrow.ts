import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { BigNumberish, keccak256 } from 'ethers';
import { IEscrow, convertEscrow as convertEscrow } from './util';

describe('PolyEscrow', function () {
    let securityContext: any;
    let systemSettings: any;
    let polyEscrow: any;
    let testToken: any;
    let admin: HardhatEthersSigner;
    let nonOwner: HardhatEthersSigner;
    let payer1: HardhatEthersSigner;
    let payer2: HardhatEthersSigner;
    let receiver1: HardhatEthersSigner;
    let receiver2: HardhatEthersSigner;
    let vaultAddress: HardhatEthersSigner;
    let arbiter1: HardhatEthersSigner;
    let arbiter2: HardhatEthersSigner;

    async function getBalance(address: any, isToken = false) {
        return isToken
            ? await await testToken.balanceOf(address)
            : await admin.provider.getBalance(address);
    }

    async function createEscrow(
        escrowId: string,
        payerAccount: HardhatEthersSigner,
        receiverAddress: string,
        amount: BigNumberish,
        isToken: boolean = false
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
            arbiters: [],
            arbitersRequired: 0,
            amount,
            startTime: 0,
            endTime: 0,
        });

        //return escrow
        const escrow = convertEscrow(await polyEscrow.getEscrow(escrowId));
        return escrow;
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
        if (expectedValues.arbiterAssent) {
            expect(escrow.arbiterAssent?.length ?? 0).to.equal(
                expectedValues.arbiterAssent.length
            );
            for (let n = 0; n < escrow.arbiterAssent.length; n++) {
                expect(escrow.arbiterAssent[n]).to.equal(
                    expectedValues.arbiterAssent[n]
                );
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
            admin.address,
            0
        );

        //deploy test token
        const TestTokenFactory =
            await hre.ethers.getContractFactory('TestToken');
        testToken = await TestTokenFactory.deploy('XYZ', 'ZYX');

        //grant roles
        const PolyEscrowFactory =
            await hre.ethers.getContractFactory('PolyEscrow');
        polyEscrow = await PolyEscrowFactory.deploy(
            securityContext.target,
            systemSettings.target
        );

        //grant token
        await testToken.mint(nonOwner, 10000000000);
        await testToken.mint(payer1, 10000000000);
        await testToken.mint(payer2, 10000000000);
    });

    describe('Deployment', function () {
        it('Should set the right arbiter role', async function () {});
    });

    describe('Create Escrows', function () {
        describe('Happy Paths', function () {
            it('can create a new native currency escrow', async function () {
                const amount = 10000000;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');

                //escrow is created in contract with right values
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount
                );
                verifyEscrow(escrow, {
                    id: escrowId,
                    payer: payer1.address,
                    receiver: receiver1.address,
                    arbiters: [],
                    arbiterAssent: [],
                    arbitersRequired: 0,
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

            it('can create a new token currency escrow', async function () {
                const amount = 10000000;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');

                //escrow is logged in contract with right values
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
                );
                verifyEscrow(escrow, {
                    id: escrowId,
                    payer: payer1.address,
                    receiver: receiver1.address,
                    arbiters: [],
                    arbiterAssent: [],
                    arbitersRequired: 0,
                    amount,
                    currency: testToken.target,
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

            //can create an escrow with multiple arbiters

            //can create an escrow with start & end dates
        });

        describe('Exceptions', function () {
            it('cannot create a new escrow with a duplicate id', async function () {
                const amount = 10000000;

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

                //create escrow
                const escrowId = ethers.keccak256('0x01');
                await expect(
                    createEscrow(escrowId, payer1, receiver1.address, amount)
                ).to.be.revertedWith('InvalidAmount');
            });

            it.skip('cannot create a new escrow with invalid ERC20', async function () {
                const amount = 10000000;

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
                    })
                ).to.be.revertedWith('InvalidToken');
            });

            it('cannot create a new escrow with invalid payer address', async function () {
                const amount = 10000000;

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
                    })
                ).to.be.revertedWith('InvalidPayer');
            });

            it('cannot create a new escrow with invalid receiver address', async function () {
                const amount = 10000000;

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
                    })
                ).to.be.revertedWith('InvalidReceiver');
            });

            it('cannot create a new escrow with more than the max number of arbiters', async function () {
                const amount = 10000000;

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
                    })
                ).to.be.revertedWith('MaxArbitersExceeded');
            });

            it('cannot create a new escrow with an invalid arbiter address', async function () {
                const amount = 10000000;

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
                    })
                ).to.be.revertedWith('InvalidArbiter');
            });

            it('cannot create a new escrow with the payer as arbiter', async function () {
                const amount = 10000000;

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
                    })
                ).to.be.revertedWith('InvalidArbiter');
            });

            it('cannot create a new escrow with the receiver as arbiter', async function () {
                const amount = 10000000;

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
                    })
                ).to.be.revertedWith('InvalidArbiter');
            });

            it('cannot create escrow where payer & receiver are the same', async function () {
                const amount = 10000000;

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
                    })
                ).to.be.revertedWith('InvalidReceiver');
            });
        });

        describe('Events', function () {
            it('emits EscrowCreated', async function () {
                const amount = BigInt(10000000);

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
            it('can place a single native payment', async function () {
                const initialContractBalance = await getBalance(
                    polyEscrow.target
                );
                const initialPayerBalance = await getBalance(payer1.address);
                const amount = BigInt(10000000);

                //create escrow
                const escrowId = ethers.keccak256('0x01');
                let escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount
                );

                //place a payment
                escrow = await placePayment(escrowId, payer1, amount, false);

                expect(escrow.amountPaid).to.equal(amount);
                expect(escrow.fullyPaid).to.equal(true);

                const newContractBalance = await getBalance(polyEscrow.target);
                const newPayerBalance = await getBalance(payer1.address);

                expect(newContractBalance).to.equal(
                    initialContractBalance + amount
                );
                expect(newPayerBalance).to.be.lessThan(
                    initialPayerBalance - amount
                );
            });

            it('can place a single token payment', async function () {
                const initialContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const initialPayerBalance = await getBalance(
                    payer1.address,
                    true
                );
                const amount = BigInt(10000000);

                //create escrow
                const escrowId = ethers.keccak256('0x01');
                let escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
                );

                //place a payment
                escrow = await placePayment(escrowId, payer1, amount, true);

                expect(escrow.amountPaid).to.equal(amount);
                expect(escrow.fullyPaid).to.equal(true);

                const newContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const newPayerBalance = await getBalance(payer1.address, true);

                expect(newContractBalance).to.equal(
                    initialContractBalance + amount
                );
                expect(newPayerBalance).to.equal(initialPayerBalance - amount);
            });

            it('paid token amounts accrue in contract', async function () {
                const amount1 = 10000000;
                const amount2 = 20000000;
                const amount3 = 30000000;

                const escrowId1 = ethers.keccak256('0x01');
                const escrowId2 = ethers.keccak256('0x02');
                const escrowId3 = ethers.keccak256('0x03');

                //create escrows
                await createEscrow(
                    escrowId1,
                    payer1,
                    receiver1.address,
                    amount1,
                    true
                );
                await createEscrow(
                    escrowId2,
                    payer1,
                    receiver1.address,
                    amount2,
                    true
                );
                await createEscrow(
                    escrowId3,
                    payer2,
                    receiver1.address,
                    amount3,
                    true
                );

                //pass 2 payments
                await placePayment(escrowId1, payer1, amount1, true);
                await placePayment(escrowId2, payer1, amount2, true);

                //check balance accrual
                expect(await getBalance(polyEscrow.target, true)).to.equal(
                    amount1 + amount2
                );

                //pass another payment
                await placePayment(escrowId3, payer2, amount3, true);

                //check balance accrual
                expect(await getBalance(polyEscrow.target, true)).to.equal(
                    amount1 + amount2 + amount3
                );
            });

            it('paid native amounts accrue in contract', async function () {
                const amount1 = 10000000;
                const amount2 = 20000000;
                const amount3 = 30000000;

                const escrowId1 = ethers.keccak256('0x01');
                const escrowId2 = ethers.keccak256('0x02');
                const escrowId3 = ethers.keccak256('0x03');

                //create escrows
                await createEscrow(
                    escrowId1,
                    payer1,
                    receiver1.address,
                    amount1
                );
                await createEscrow(
                    escrowId2,
                    payer1,
                    receiver1.address,
                    amount2
                );
                await createEscrow(
                    escrowId3,
                    payer2,
                    receiver1.address,
                    amount3
                );

                //pass 2 payments
                await placePayment(escrowId1, payer1, amount1);
                await placePayment(escrowId2, payer1, amount2);

                //check balance accrual
                expect(await getBalance(polyEscrow.target)).to.equal(
                    amount1 + amount2
                );

                //pass another payment
                await placePayment(escrowId3, payer2, amount3);

                //check balance accrual
                expect(await getBalance(polyEscrow.target)).to.equal(
                    amount1 + amount2 + amount3
                );
            });
        });

        //TODO: verify appropriate escrow properties in each sad path case
        describe('Exceptions', function () {
            it('cannot place payment to nonexistent escrow', async function () {
                const amount = 10000000;

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

                //place the payment with less than required amount
                const escrowId = ethers.keccak256('0x01');

                await createEscrow(escrowId, payer1, receiver1.address, amount);

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

                //place the payment with less than required amount
                const escrowId = ethers.keccak256('0x01');

                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
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
                    true
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
                const invalidTokenCurrency =
                    '0x0000000000000000000000000000000000000022';

                //create the escrow for token
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
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

            //cannot place payment if escrow is already released

            //cannot place payment if escrow is in arbitration

            //cannot place payment if escrow is not yet active

            //failed token payment
        });

        describe('Events', function () {
            it('emits EscrowFullyPaid for native payment', async function () {
                const amount = BigInt(10000000);

                //create escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(escrowId, payer1, receiver1.address, amount);

                //place a payment
                await expect(
                    polyEscrow.connect(payer1).placePayment(
                        {
                            escrowId: escrowId,
                            currency: ethers.ZeroAddress,
                            amount,
                        },
                        { value: amount }
                    )
                )
                    .to.emit(polyEscrow, 'EscrowFullyPaid')
                    .withArgs(escrowId, amount);
            });

            it('emits EscrowFullyPaid for token payment', async function () {
                const amount = BigInt(10000000);

                //create escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(escrowId, payer1, receiver1.address, amount);

                //place a payment
                await testToken
                    .connect(payer1)
                    .approve(polyEscrow.target, amount);
                await expect(
                    polyEscrow.connect(payer1).placePayment(
                        {
                            escrowId: escrowId,
                            currency: ethers.ZeroAddress,
                            amount,
                        },
                        { value: amount }
                    )
                )
                    .to.emit(polyEscrow, 'EscrowFullyPaid')
                    .withArgs(escrowId, amount);
            });

            it('does not emit EscrowFullyPaid for partial payment', async function () {
                const amount = BigInt(10000000);

                //create escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
                );

                //place a payment
                await testToken
                    .connect(payer1)
                    .approve(polyEscrow.target, amount);
                await expect(
                    polyEscrow.connect(payer1).placePayment({
                        escrowId: escrowId,
                        currency: testToken.target,
                        amount: amount - BigInt(1),
                    })
                ).to.not.emit(polyEscrow, 'EscrowFullyPaid');
            });

            it('emits PaymentReceived for partial native payment', async function () {
                const amount = BigInt(10000000);
                const partialAmount = amount / BigInt(2);

                //create escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(escrowId, payer1, receiver1.address, amount);

                //place a payment
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
            });

            it('emits PaymentReceived for partial token payment', async function () {
                const amount = BigInt(10000000);
                const partialAmount = amount / BigInt(2);

                //create escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
                );

                //place a payment
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
                    .to.emit(polyEscrow, 'PaymentReceived')
                    .withArgs(escrowId, payer1.address, partialAmount);
            });

            it('emits PaymentReceived and EscrowFullyPaid for token payment', async function () {
                const amount = BigInt(10000000);
                const partialAmount = amount / BigInt(2);

                //create escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
                );

                //place a payment
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
            });
        });
    });

    describe('Release Escrows', function () {
        describe('Happy Paths', function () {
            it('can release a native payment with both approvals', async function () {
                const initialContractBalance = await getBalance(
                    polyEscrow.target
                );
                const initialReceiverBalance = await getBalance(
                    receiver1.address
                );
                const amount = 10000000;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(escrowId, payer1, receiver1.address, amount);

                //fully pay the escrow
                await placePayment(escrowId, payer1, amount);

                //check the balance
                const newContractBalance = await getBalance(polyEscrow.target);
                const newReceiverBalance = await getBalance(receiver1.address);
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
                    currency: ethers.ZeroAddress,
                });

                //check the balance
                const finalContractBalance = await getBalance(
                    polyEscrow.target
                );
                const finalReceiverBalance = await getBalance(
                    receiver1.address
                );
                expect(finalContractBalance).to.equal(
                    newContractBalance - BigInt(amount)
                );
            });

            it('can release a token payment with both approvals', async function () {
                const initialContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const initialReceiverBalance = await getBalance(
                    receiver1.address,
                    true
                );
                const amount = 10000000;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
                );

                //fully pay the escrow
                await placePayment(escrowId, payer1, amount, true);

                //check the balance
                const newContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const newReceiverBalance = await getBalance(
                    receiver1.address,
                    true
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
                    currency: testToken.target,
                });

                //check the balance
                const finalContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const finalReceiverBalance = await getBalance(
                    receiver1.address,
                    true
                );
                expect(finalContractBalance).to.equal(
                    newContractBalance - BigInt(amount)
                );
            });

            it.skip('arbiter can release a payment on behalf of payer', async function () {
                const initialContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const initialReceiverBalance = await getBalance(
                    receiver1.address,
                    true
                );
                const amount = 10000000;

                //place the payment
                const escrowId = ethers.keccak256('0x01');
                await testToken
                    .connect(payer1)
                    .approve(polyEscrow.target, amount);
                await polyEscrow.connect(payer1).placePayment(
                    {
                        currency: testToken.target,
                        escrowId: escrowId,
                        receiver: receiver1.address,
                        payer: payer1.address,
                        amount,
                    },
                    { value: amount }
                );

                //check the balance
                const newContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const newReceiverBalance = await getBalance(
                    receiver1.address,
                    true
                );
                expect(newContractBalance).to.equal(
                    initialContractBalance + BigInt(amount)
                );
                expect(newReceiverBalance).to.equal(initialReceiverBalance);

                //try to release the payment
                await polyEscrow.connect(receiver1).releaseEscrow(escrowId);
                await polyEscrow.connect(arbiter1).releaseEscrow(escrowId);

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
                    payerReleased: true,
                    receiverReleased: true,
                    released: true,
                    currency: testToken.target,
                });

                //check the balance
                const finalContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const finalReceiverBalance = await getBalance(
                    receiver1.address,
                    true
                );
                expect(finalContractBalance).to.equal(
                    newContractBalance - BigInt(amount)
                );
                expect(finalReceiverBalance).to.equal(
                    newReceiverBalance + BigInt(amount)
                );
            });
        });

        describe.skip('Exceptions', function () {
            it('cannot release a payment with no approvals', async function () {
                const initialContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const amount = 10000000;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
                );

                //check the balance
                const newContractBalance = await getBalance(polyEscrow.target);
                expect(newContractBalance).to.equal(
                    initialContractBalance + BigInt(amount)
                );

                //try to release the payment
                await expect(
                    polyEscrow.connect(arbiter1).releaseEscrow(escrowId)
                ).to.not.be.reverted;

                //ensure that nothing has been released
                const payment = convertEscrow(
                    await polyEscrow.getEscrow(escrowId)
                );
                verifyEscrow(payment, {
                    id: escrowId,
                    payer: payer1.address,
                    receiver: receiver1.address,
                });

                //check the balance
                const finalContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                expect(finalContractBalance).to.equal(newContractBalance);
            });

            it('cannot release a payment with only payer approval', async function () {
                const initialContractBalance = await getBalance(
                    polyEscrow.target
                );
                const amount = 10000000;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(escrowId, payer1, receiver1.address, amount);

                //check the balance
                const newContractBalance = await getBalance(polyEscrow.target);
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
                    currency: ethers.ZeroAddress,
                });

                //check the balance
                const finalContractBalance = await getBalance(
                    polyEscrow.target
                );
                expect(finalContractBalance).to.equal(newContractBalance);
            });

            it('cannot release a payment with only receiver approval', async function () {
                const initialContractBalance = await getBalance(
                    polyEscrow.target
                );
                const amount = 10000000;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(escrowId, payer1, receiver1.address, amount);

                //check the balance
                const newContractBalance = await getBalance(polyEscrow.target);
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
                    currency: ethers.ZeroAddress,
                });

                //check the balance
                const finalContractBalance = await getBalance(
                    polyEscrow.target
                );
                expect(finalContractBalance).to.equal(newContractBalance);
            });

            it('not possible to release a payment for which one is not a party', async function () {
                const initialContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const amount = 10000000;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
                );

                //check the balance
                const newContractBalance = await getBalance(polyEscrow.target);
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
                    true
                );
                expect(finalContractBalance).to.equal(newContractBalance);
            });

            it('not possible to release a payment twice', async function () {
                const initialContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const initialReceiverBalance = await getBalance(
                    receiver1.address,
                    true
                );
                const amount = 10000000;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
                );

                //check the balance
                const newContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const newReceiverBalance = await getBalance(
                    receiver1.address,
                    true
                );
                expect(newContractBalance).to.equal(
                    initialContractBalance + BigInt(amount)
                );
                expect(newReceiverBalance).to.equal(initialReceiverBalance);

                //try to release the payment
                await polyEscrow.connect(receiver1).releaseEscrow(escrowId);
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
                    receiverReleased: true,
                    released: true,
                    currency: testToken.target,
                });

                //try to release the payment a second time
                await polyEscrow.connect(receiver1).releaseEscrow(escrowId);
                await polyEscrow.connect(payer1).releaseEscrow(escrowId);

                //check the balance
                const finalContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const finalReceiverBalance = await getBalance(
                    receiver1.address,
                    true
                );
                expect(finalContractBalance).to.equal(
                    newContractBalance - BigInt(amount)
                );
                expect(finalReceiverBalance).to.equal(
                    newReceiverBalance + BigInt(amount)
                );
            });
        });

        describe.skip('Events', function () {});
    });

    describe.skip('Refund Payments', function () {
        async function refundTest(
            amount: number,
            refundAmount: number,
            payerAccount: HardhatEthersSigner,
            receiverAccount: HardhatEthersSigner,
            refunderAccount: HardhatEthersSigner
        ): Promise<string> {
            const initialContractBalance = await getBalance(
                polyEscrow.target,
                true
            );
            const initialPayerBalance = await getBalance(
                payerAccount.address,
                true
            );

            //create the escrow
            const escrowId = ethers.keccak256('0x01');
            await createEscrow(
                escrowId,
                payerAccount,
                receiverAccount.address,
                amount,
                true
            );

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
                true
            );
            const finalPayerBalance = await getBalance(
                payerAccount.address,
                true
            );

            expect(finalContractBalance).to.equal(
                initialContractBalance + BigInt(amount - refundAmount)
            );
            expect(finalPayerBalance).to.equal(
                initialPayerBalance - BigInt(amount - refundAmount)
            );

            return escrowId;
        }

        describe('Happy Paths', function () {
            it('arbiter can cause a partial refund', async function () {
                const amount = 1000000;
                await refundTest(
                    amount,
                    amount / 5,
                    payer1,
                    receiver1,
                    arbiter1
                );
            });

            it('receiver can cause a partial refund', async function () {
                const amount = 1000000;
                await refundTest(
                    amount,
                    amount / 5,
                    payer1,
                    receiver1,
                    receiver1
                );
            });

            it('arbiter can cause a full refund', async function () {
                const amount = 1000000;
                await refundTest(amount, amount, payer1, receiver1, arbiter1);
            });

            it('receiver can cause a full refund', async function () {
                const amount = 1000000;
                await refundTest(amount, amount, payer1, receiver1, receiver1);
            });

            it('can do multiple partial refunds', async function () {
                const amount = 1000000;
                const refundAmount = amount / 5;
                const initialContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const initialPayerBalance = await getBalance(
                    payer1.address,
                    true
                );

                //initial refund
                const escrowId = await refundTest(
                    amount,
                    refundAmount,
                    payer1,
                    receiver1,
                    receiver1
                );

                //partially refund the payment
                await polyEscrow
                    .connect(arbiter1)
                    .refundPayment(escrowId, amount / 5);

                //get & check the payment - was it refunded?
                const payment = convertEscrow(
                    await polyEscrow.getEscrow(escrowId)
                );
                expect(payment.amountRefunded).to.equal(refundAmount * 2);
                expect(payment.amount).to.equal(amount);

                //check the balances
                const finalContractBalance = await getBalance(
                    polyEscrow.target,
                    true
                );
                const finalPayerBalance = await getBalance(
                    payer1.address,
                    true
                );

                expect(finalContractBalance).to.equal(
                    initialContractBalance + BigInt(amount - refundAmount * 2)
                );
                expect(finalPayerBalance).to.equal(
                    initialPayerBalance - BigInt(amount - refundAmount * 2)
                );
            });
        });

        describe('Exceptions', function () {
            it('not possible to refund a payment to which one is not a party', async function () {
                const amount = 100000000;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
                );

                //attempt to refund non-authorized
                await expect(
                    polyEscrow.connect(payer1).refundPayment(escrowId, amount)
                ).to.be.reverted;

                //attempt to refund authorized
                await expect(
                    polyEscrow.connect(arbiter1).refundPayment(escrowId, amount)
                ).to.not.be.reverted;
            });

            it('not possible to refund more than the payment amount', async function () {
                const amount = 100000000;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
                );

                //attempt to refund more than one should
                await expect(
                    polyEscrow
                        .connect(arbiter1)
                        .refundPayment(escrowId, amount + 1)
                ).to.be.revertedWith('AmountExceeded');

                //attempt to refund normal amount
                await expect(
                    polyEscrow.connect(arbiter1).refundPayment(escrowId, amount)
                ).to.not.be.reverted;
            });

            it('not possible to refund more than the payment amount, using multiple refunds', async function () {
                const amount = 100000000;

                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
                );

                //refunds that should be allowed
                await expect(
                    polyEscrow
                        .connect(arbiter1)
                        .refundPayment(escrowId, amount - 2)
                ).to.not.be.reverted;
                await expect(
                    polyEscrow.connect(arbiter1).refundPayment(escrowId, 1)
                ).to.not.be.reverted;

                //attempt to refund more than one should
                await expect(
                    polyEscrow.connect(arbiter1).refundPayment(escrowId, 100)
                ).to.be.revertedWith('AmountExceeded');

                //attempt to refund normal amount
                await expect(
                    polyEscrow.connect(arbiter1).refundPayment(escrowId, 1)
                ).to.not.be.reverted;
            });
        });

        describe('Events', function () {});
    });

    describe.skip('Fee Amounts', function () {
        const feeBps = 200;

        this.beforeEach(async () => {});

        describe('Happy Paths', function () {
            it('fees are calculated correctly', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const receiverInitialAmount = await getBalance(
                    receiver1.address,
                    true
                );

                //ensure that dao balance at start is 0
                expect(await getBalance(vaultAddress, true)).to.equal(0);

                //place a payment
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
                );

                //release the payment from escrow
                await polyEscrow.connect(payer1).releaseEscrow(escrowId);
                await polyEscrow.connect(receiver1).releaseEscrow(escrowId);

                //fee should be in the vault
                const feeAmount = amount * (feeBps / 10000);
                expect(await getBalance(vaultAddress, true)).to.equal(
                    feeAmount
                );

                //remainder amount should have gone to the receiver
                expect(await getBalance(receiver1.address, true)).to.equal(
                    receiverInitialAmount + BigInt(amount - feeAmount)
                );
            });

            it('fee can be 0%', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const receiverInitialAmount = await getBalance(
                    receiver1.address,
                    true
                );

                //ensure that dao balance at start is 0
                expect(await getBalance(vaultAddress, true)).to.equal(0);

                //place a payment
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
                );

                //release the payment from escrow
                await polyEscrow.connect(payer1).releaseEscrow(escrowId);
                await polyEscrow.connect(receiver1).releaseEscrow(escrowId);

                //no fees should have gone to the vault
                expect(await getBalance(vaultAddress, true)).to.equal(0);

                //full amount should have gone to the receiver
                expect(await getBalance(receiver1.address, true)).to.equal(
                    receiverInitialAmount + BigInt(amount)
                );
            });

            it('fee is calculated from amount remaining after refund', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const refundAmount = 40000;
                const receiverInitialAmount = await getBalance(
                    receiver1.address,
                    true
                );

                //ensure that dao balance at start is 0
                expect(await getBalance(vaultAddress, true)).to.equal(0);

                //place a payment
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
                );

                //refund a small amount
                await polyEscrow
                    .connect(arbiter1)
                    .refundPayment(escrowId, refundAmount);

                //release the payment from escrow
                await polyEscrow.connect(payer1).releaseEscrow(escrowId);
                await polyEscrow.connect(receiver1).releaseEscrow(escrowId);

                //fee should be in the vault
                const feeAmount = (amount - refundAmount) * (feeBps / 10000);
                expect(await getBalance(vaultAddress, true)).to.equal(
                    (amount - refundAmount) * (feeBps / 10000)
                );

                //remainder should have gone to receiver
                expect(await getBalance(receiver1.address, true)).to.equal(
                    receiverInitialAmount +
                        BigInt(amount - refundAmount - feeAmount)
                );
            });

            it('no fee is taken from fully refunded payment', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000000;
                const refundAmount = amount;
                const receiverInitialAmount = await getBalance(
                    receiver1.address,
                    true
                );

                //ensure that dao balance at start is 0
                expect(await getBalance(vaultAddress, true)).to.equal(0);

                //place a payment
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    true
                );

                //refund all
                await polyEscrow
                    .connect(arbiter1)
                    .refundPayment(escrowId, refundAmount);

                //release the payment from escrow
                await polyEscrow.connect(payer1).releaseEscrow(escrowId);
                await polyEscrow.connect(receiver1).releaseEscrow(escrowId);

                //no fee should be in the vault
                expect(await getBalance(vaultAddress, true)).to.equal(0);

                //none should have gone to receiver
                expect(await getBalance(receiver1.address, true)).to.equal(
                    receiverInitialAmount
                );
            });
        });

        describe('Exceptions', function () {});

        describe('Events', function () {});
    });

    describe.skip('Edge Cases', function () {
        it('payer and receiver are the same', async function () {
            const initialPayerBalance = await getBalance(payer1.address, true);
            const amount = 10000000;

            //create the escrow
            const escrowId = ethers.keccak256('0x01');
            await createEscrow(escrowId, payer1, payer1.address, amount, true);

            //check the balance
            const newPayerBalance = await getBalance(payer1.address, true);
            expect(newPayerBalance).to.equal(
                initialPayerBalance - BigInt(amount)
            );

            //try to release the payment
            await polyEscrow.connect(payer1).releaseEscrow(escrowId);
            await polyEscrow.connect(payer1).releaseEscrow(escrowId);

            //ensure that payment has been released
            const payment = convertEscrow(await polyEscrow.getEscrow(escrowId));
            verifyEscrow(payment, {
                id: escrowId,
                payer: payer1.address,
                receiver: payer1.address,
                amount,
                amountRefunded: 0,
                payerReleased: true,
                receiverReleased: true,
                released: true,
                currency: testToken.target,
            });

            //check the balance
            const finalPayerBalance = await getBalance(payer1.address, true);
            expect(finalPayerBalance).to.equal(initialPayerBalance);
        });
    });
});
