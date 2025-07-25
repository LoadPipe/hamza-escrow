import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { BigNumberish, keccak256 } from 'ethers';
import { IEscrow, convertEscrow as convertEscrow } from './util';

describe('RelayNode', function () {
    let securityContext: any;
    let systemSettings: any;
    let polyEscrow: any;
    let relayNode: any;
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

    async function getBalance(address: any, isToken = false) {
        return isToken
            ? await await testToken.balanceOf(address)
            : await admin.provider.getBalance(address);
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

    async function getAndVerifyEscrow(escrowId: string, expectedValues: any) {
        const escrow = convertEscrow(await polyEscrow.getEscrow(escrowId));
        verifyEscrow(escrow, expectedValues);
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

        //deploy arbitration module
        const EscrowArbitrationModuleFactory =
            await hre.ethers.getContractFactory('EscrowArbitrationModule');
        arbitrationModule = await EscrowArbitrationModuleFactory.deploy();

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
        it('can deploy relay node', async function () {
            //deploy escrow
            const escrowId = ethers.keccak256('0x01');

            await createEscrow(escrowId, payer1, receiver1.address, 1000, true);

            //deploy relay node
            const RelayNodeFactory =
                await hre.ethers.getContractFactory('RelayNode');
            relayNode = await RelayNodeFactory.deploy(
                securityContext.target,
                polyEscrow.target,
                escrowId
            );

            expect(await relayNode.escrowId()).to.equal(escrowId);
        });

        it('cannot deploy relay node with invalid escrow id', async function () {
            //deploy relay node
            const RelayNodeFactory =
                await hre.ethers.getContractFactory('RelayNode');
            await expect(
                RelayNodeFactory.deploy(
                    securityContext.target,
                    polyEscrow.target,
                    ethers.keccak256('0x01')
                )
            ).to.be.revertedWith('InvalidEscrow');
        });
    });

    describe('Relay', function () {
        describe('Happy Paths', function () {
            it('can relay a native payment', async function () {
                const isToken: boolean = false;

                //deploy escrow
                const escrowId = ethers.keccak256('0x01');
                const amount = BigInt(10000000);

                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //deploy relay node
                const RelayNodeFactory =
                    await hre.ethers.getContractFactory('RelayNode');
                relayNode = await RelayNodeFactory.deploy(
                    securityContext.target,
                    polyEscrow.target,
                    escrowId
                );

                expect(await relayNode.escrowId()).to.equal(escrowId);

                //initial balances
                const initialRelayBalance = await getBalance(
                    relayNode.target,
                    isToken
                );
                const initialPayerBalance = await getBalance(
                    payer1.address,
                    isToken
                );
                const initialEscrowBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );

                //verify escrow
                await getAndVerifyEscrow(escrowId, {
                    fullyPaid: false,
                    amountPaid: 0,
                    amount: amount,
                    currency: ethers.ZeroAddress,
                });

                //pay into the relay
                const tx = await payer1.sendTransaction({
                    to: relayNode.target,
                    value: amount,
                });
                await tx.wait();

                //verify the relay was paid
                let newRelayBalance = await getBalance(
                    relayNode.target,
                    isToken
                );
                let newPayerBalance = await getBalance(payer1.address, isToken);
                expect(newRelayBalance).to.equal(initialRelayBalance + amount);
                expect(newPayerBalance).to.be.lessThan(
                    initialPayerBalance - amount
                );

                //pump the relay
                await relayNode.relay();

                //check the balances
                newRelayBalance = await getBalance(relayNode.target, isToken);
                newPayerBalance = await getBalance(payer1.address, isToken);
                let newEscrowBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );

                expect(newRelayBalance).to.equal(initialRelayBalance);
                expect(newPayerBalance).to.be.lessThan(
                    initialPayerBalance - amount
                );
                expect(newEscrowBalance).to.equal(
                    initialEscrowBalance + amount
                );

                //verify escrow
                await getAndVerifyEscrow(escrowId, {
                    fullyPaid: true,
                    amountPaid: amount,
                    amount: amount,
                });
            });

            it('can relay a token payment', async function () {
                const isToken: boolean = true;

                //deploy escrow
                const escrowId = ethers.keccak256('0x01');
                const amount = BigInt(10000000);

                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken
                );

                //deploy relay node
                const RelayNodeFactory =
                    await hre.ethers.getContractFactory('RelayNode');
                relayNode = await RelayNodeFactory.deploy(
                    securityContext.target,
                    polyEscrow.target,
                    escrowId
                );

                expect(await relayNode.escrowId()).to.equal(escrowId);

                //initial balances
                const initialRelayBalance = await getBalance(
                    relayNode.target,
                    isToken
                );
                const initialPayerBalance = await getBalance(
                    payer1.address,
                    isToken
                );
                const initialEscrowBalance = await getBalance(
                    polyEscrow.target,
                    isToken
                );

                //verify escrow
                await getAndVerifyEscrow(escrowId, {
                    fullyPaid: false,
                    amountPaid: 0,
                    amount: amount,
                });

                //pay into the relay
                await testToken
                    .connect(payer1)
                    .transfer(relayNode.target, amount);

                //verify the relay was paid
                let newRelayBalance = await getBalance(
                    relayNode.target,
                    isToken
                );
                let newPayerBalance = await getBalance(payer1.address, isToken);
                expect(newRelayBalance).to.equal(initialRelayBalance + amount);
                expect(newPayerBalance).to.equal(initialPayerBalance - amount);

                //pump the relay
                await relayNode.relay();

                //check the balances
                newRelayBalance = await getBalance(relayNode.target, isToken);
                newPayerBalance = await getBalance(payer1.address, isToken);
                let newEscrowBalance = await getBalance(
                    polyEscrow.target,
                    true
                );

                expect(newRelayBalance).to.equal(initialRelayBalance);
                expect(newPayerBalance).to.equal(initialPayerBalance - amount);
                expect(newEscrowBalance).to.equal(
                    initialEscrowBalance + amount
                );

                //verify escrow
                await getAndVerifyEscrow(escrowId, {
                    fullyPaid: true,
                    amountPaid: amount,
                    amount: amount,
                });
            });

            //TODO: can relay a native partial payment

            //TODO: can relay a token partial payment

            //TODO: can mix direct and relayed payments
        });

        describe('Exceptions', function () {
            //TODO: cannot relay the wrong currency
        });

        describe('Events', function () {});
    });
});
