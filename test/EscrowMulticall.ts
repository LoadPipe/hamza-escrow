import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { BigNumberish, keccak256 } from 'ethers';
import { IPayment, convertPayment } from './util';
import { EscrowMulticall } from '../typechain-types';

describe('EscrowMulticall', function () {
    let securityContext: any;
    let escrow: any;
    let escrow1: any;
    let escrow2: any;
    let escrow3: any;
    let testToken: any;
    let systemSettings: any;
    let admin: HardhatEthersSigner;
    let nonOwner: HardhatEthersSigner;
    let payer1: HardhatEthersSigner;
    let payer2: HardhatEthersSigner;
    let payer3: HardhatEthersSigner;
    let receiver1: HardhatEthersSigner;
    let receiver2: HardhatEthersSigner;
    let receiver3: HardhatEthersSigner;
    let vaultAddress: HardhatEthersSigner;
    let arbiter: HardhatEthersSigner;
    let dao: HardhatEthersSigner;
    let multicall: EscrowMulticall;

    const ARBITER_ROLE =
        '0xbb08418a67729a078f87bbc8d02a770929bb68f5bfdf134ae2ead6ed38e2f4ae';

    const DAO_ROLE =
        '0x3b5d4cc60d3ec3516ee8ae083bd60934f6eb2a6c54b1229985c41bfb092b2603';

    this.beforeEach(async () => {
        const [a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11] =
            await hre.ethers.getSigners();
        admin = a1;
        nonOwner = a2;
        vaultAddress = a3;
        payer1 = a4;
        payer2 = a5;
        payer3 = a6;
        receiver1 = a7;
        receiver2 = a8;
        receiver3 = a9;
        arbiter = a10;
        dao = a11;

        //deploy security context
        const SecurityContextFactory =
            await hre.ethers.getContractFactory('SecurityContext');
        securityContext = await SecurityContextFactory.deploy(admin.address);

        //deploy test token
        const TestTokenFactory =
            await hre.ethers.getContractFactory('TestToken');
        testToken = await TestTokenFactory.deploy('XYZ', 'ZYX');

        //deploy settings
        const SystemSettingsFactory =
            await hre.ethers.getContractFactory('SystemSettings');
        systemSettings = await SystemSettingsFactory.deploy(
            securityContext.target,
            vaultAddress,
            0
        );

        //deploy escrow
        const PaymentEscrowFactory =
            await hre.ethers.getContractFactory('PaymentEscrow');
        escrow = await PaymentEscrowFactory.deploy(
            securityContext.target,
            systemSettings.target,
            false
        );
        escrow2 = await PaymentEscrowFactory.deploy(
            securityContext.target,
            systemSettings.target,
            false
        );
        escrow3 = await PaymentEscrowFactory.deploy(
            securityContext.target,
            systemSettings.target,
            false
        );
        escrow1 = escrow;

        //deploy multicall
        const EscrowMulticallFactory =
            await hre.ethers.getContractFactory('EscrowMulticall');
        multicall = await EscrowMulticallFactory.deploy();

        //grant roles
        await securityContext
            .connect(admin)
            .grantRole(ARBITER_ROLE, vaultAddress);

        await securityContext
            .connect(admin)
            .grantRole(ARBITER_ROLE, arbiter.address);

        await securityContext.connect(admin).grantRole(DAO_ROLE, dao.address);

        //grant token
        await testToken.mint(nonOwner, 10000000000);
        await testToken.mint(payer1, 10000000000);
        await testToken.mint(payer2, 10000000000);
        await testToken.mint(payer3, 10000000000);
    });

    describe('Deployment', function () {
        it('Should set the right arbiter role', async function () {
            expect(await securityContext.hasRole(ARBITER_ROLE, arbiter.address))
                .to.be.true;
            expect(
                await securityContext.hasRole(ARBITER_ROLE, nonOwner.address)
            ).to.be.false;
            expect(await securityContext.hasRole(ARBITER_ROLE, vaultAddress)).to
                .be.true;
        });
    });

    async function getBalance(address: any, isToken = false) {
        return isToken
            ? await await testToken.balanceOf(address)
            : await admin.provider.getBalance(address);
    }

    async function placePayment(
        paymentId: string,
        payerAccount: HardhatEthersSigner,
        receiverAddress: string,
        amount: BigNumberish,
        isToken: boolean = false
    ): Promise<IPayment> {
        if (isToken)
            await testToken
                .connect(payerAccount)
                .approve(multicall.target, amount);

        await multicall.connect(payerAccount).multipay(
            [
                {
                    contractAddress: escrow.target,
                    currency: isToken ? testToken.target : ethers.ZeroAddress,
                    id: paymentId,
                    receiver: receiverAddress,
                    payer: payerAccount.address,
                    amount,
                },
            ],
            { value: isToken ? 0 : amount }
        );

        //payment is logged in contract with right values
        const payment = convertPayment(await escrow.getPayment(paymentId));
        return payment;
    }

    function verifyPayment(actualPayment: IPayment, expectedPayment: IPayment) {
        expect(actualPayment.id).to.equal(expectedPayment.id);
        expect(actualPayment.payer).to.equal(expectedPayment.payer);
        expect(actualPayment.receiver).to.equal(expectedPayment.receiver);
        expect(actualPayment.amount).to.equal(expectedPayment.amount);
        expect(actualPayment.amountRefunded).to.equal(
            expectedPayment.amountRefunded
        );
        expect(actualPayment.currency).to.equal(expectedPayment.currency);
        expect(actualPayment.receiverReleased).to.equal(
            expectedPayment.receiverReleased
        );
        expect(actualPayment.payerReleased).to.equal(
            expectedPayment.payerReleased
        );
        expect(actualPayment.released).to.equal(expectedPayment.released);
    }

    describe('Place Payments', function () {
        it('can place a single native payment', async function () {
            const initialContractBalance = await getBalance(escrow.target);
            const initialPayerBalance = await getBalance(payer1.address);
            const amount = 10000000;

            //place the payment
            const paymentId = ethers.keccak256('0x01');

            //payment is logged in contract with right values
            const payment = await placePayment(
                paymentId,
                payer1,
                receiver1.address,
                amount
            );
            verifyPayment(payment, {
                id: paymentId,
                payer: payer1.address,
                receiver: receiver1.address,
                amount,
                amountRefunded: 0,
                payerReleased: false,
                receiverReleased: false,
                released: false,
                currency: ethers.ZeroAddress,
            });

            const newContractBalance = await getBalance(escrow.target);
            const newPayerBalance = await getBalance(payer1.address);

            //amount leaves payer
            expect(newPayerBalance).to.be.lessThanOrEqual(
                initialPayerBalance - BigInt(amount)
            );

            //amount accrues in contract
            expect(newContractBalance).to.equal(
                initialContractBalance + BigInt(amount)
            );
        });

        it('can place a single token payment', async function () {
            const initialContractBalance = await getBalance(
                escrow.target,
                true
            );
            const initialPayerBalance = await getBalance(payer1.address, true);
            const amount = 10000000;

            //place the payment
            const paymentId = ethers.keccak256('0x01');

            //payment is logged in contract with right values
            const payment = await placePayment(
                paymentId,
                payer1,
                receiver1.address,
                amount,
                true
            );
            verifyPayment(payment, {
                id: paymentId,
                payer: payer1.address,
                receiver: receiver1.address,
                amount,
                amountRefunded: 0,
                payerReleased: false,
                receiverReleased: false,
                released: false,
                currency: testToken.target,
            });

            const newContractBalance = await getBalance(escrow.target, true);
            const newPayerBalance = await getBalance(payer1.address, true);

            //amount leaves payer
            expect(newPayerBalance).to.be.lessThanOrEqual(
                initialPayerBalance - BigInt(amount)
            );

            //amount accrues in contract
            expect(newContractBalance).to.equal(
                initialContractBalance + BigInt(amount)
            );
        });

        it('cannot place new order with same payment id in different transactions', async function () {
            const amount = 10000000;

            //place the payments with duplicate payment ids
            const paymentId = ethers.keccak256('0x01');

            //place a legal payment
            await placePayment(paymentId, payer1, receiver1.address, amount);

            //place the same payment again
            await expect(
                placePayment(paymentId, payer1, receiver1.address, amount)
            ).to.be.revertedWith('PaymentFailure');
        });

        it('cannot place order without correct native amount', async function () {
            const amount = 10000000;

            //place the payment with less than required amount
            const paymentId = ethers.keccak256('0x01');

            await expect(
                multicall.connect(payer1).multipay(
                    [
                        {
                            contractAddress: escrow.target,
                            currency: ethers.ZeroAddress,
                            id: paymentId,
                            receiver: receiver1,
                            payer: payer1.address,
                            amount,
                        },
                    ],
                    { value: amount - 1 }
                )
            ).to.be.revertedWith('InsufficientAmount');
        });

        it('cannot place order without correct token amount approved', async function () {
            const amount = 10000000;

            //place the payment with less than required amount
            const paymentId = ethers.keccak256('0x01');

            await testToken.connect(payer1).approve(escrow.target, amount - 1);
            await expect(
                multicall.connect(payer1).multipay([
                    {
                        contractAddress: escrow.target,
                        currency: testToken.target,
                        id: paymentId,
                        receiver: receiver1,
                        payer: payer1.address,
                        amount,
                    },
                ])
            ).to.be.reverted;
        });

        it('cannot place order without correct token amount in balance', async function () {
            const amount = 10000000;

            //give all tokens away
            await testToken
                .connect(payer1)
                .transfer(
                    payer2.address,
                    await getBalance(payer1.address, true)
                );

            //place the payment with less than required amount
            const paymentId = ethers.keccak256('0x01');

            await testToken.connect(payer1).approve(escrow.target, amount);
            await expect(
                escrow.connect(payer1).placePayment({
                    currency: testToken.target,
                    id: paymentId,
                    receiver: receiver1,
                    payer: payer1.address,
                    amount,
                })
            ).to.be.reverted;
        });
    });

    describe('Release Payments', function () {
        it('cannot release a payment with no approvals', async function () {
            const initialContractBalance = await getBalance(
                escrow.target,
                true
            );
            const amount = 10000000;

            //place the payment
            const paymentId = ethers.keccak256('0x01');

            await placePayment(
                paymentId,
                payer1,
                receiver1.address,
                amount,
                true
            );

            //check the balance
            const newContractBalance = await getBalance(escrow.target, true);
            expect(newContractBalance).to.equal(
                initialContractBalance + BigInt(amount)
            );

            //try to release the payment
            await expect(escrow.connect(arbiter).releaseEscrow(paymentId)).to
                .not.be.reverted;

            //ensure that nothing has been released
            const payment = convertPayment(await escrow.getPayment(paymentId));
            verifyPayment(payment, {
                id: paymentId,
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
            const finalContractBalance = await getBalance(escrow.target, true);
            expect(finalContractBalance).to.equal(newContractBalance);
        });

        it('cannot release a payment with only payer approval', async function () {
            const initialContractBalance = await getBalance(escrow.target);
            const amount = 10000000;

            //place the payment
            const paymentId = ethers.keccak256('0x01');

            await placePayment(paymentId, payer1, receiver1.address, amount);

            //check the balance
            const newContractBalance = await getBalance(escrow.target);
            expect(newContractBalance).to.equal(
                initialContractBalance + BigInt(amount)
            );

            //try to release the payment
            await escrow.connect(payer1).releaseEscrow(paymentId);

            //ensure that nothing has been released
            const payment = convertPayment(await escrow.getPayment(paymentId));
            verifyPayment(payment, {
                id: paymentId,
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
            const finalContractBalance = await getBalance(escrow.target);
            expect(finalContractBalance).to.equal(newContractBalance);
        });

        it('cannot release a payment with only receiver approval', async function () {
            const initialContractBalance = await getBalance(escrow.target);
            const amount = 10000000;

            //place the payment
            const paymentId = ethers.keccak256('0x01');
            await placePayment(paymentId, payer1, receiver1.address, amount);

            //check the balance
            const newContractBalance = await getBalance(escrow.target);
            expect(newContractBalance).to.equal(
                initialContractBalance + BigInt(amount)
            );

            //try to release the payment
            await escrow.connect(receiver1).releaseEscrow(paymentId);

            //ensure that nothing has been released
            const payment = convertPayment(await escrow.getPayment(paymentId));
            verifyPayment(payment, {
                id: paymentId,
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
            const finalContractBalance = await getBalance(escrow.target);
            expect(finalContractBalance).to.equal(newContractBalance);
        });

        it('can release a native payment with both approvals', async function () {
            const initialContractBalance = await getBalance(escrow.target);
            const initialReceiverBalance = await getBalance(receiver1.address);
            const amount = 10000000;

            //place the payment
            const paymentId = ethers.keccak256('0x01');
            await placePayment(paymentId, payer1, receiver1.address, amount);

            //check the balance
            const newContractBalance = await getBalance(escrow.target);
            const newReceiverBalance = await getBalance(receiver1.address);
            expect(newContractBalance).to.equal(
                initialContractBalance + BigInt(amount)
            );
            expect(newReceiverBalance).to.equal(initialReceiverBalance);

            //try to release the payment
            await escrow.connect(receiver1).releaseEscrow(paymentId);
            await escrow.connect(payer1).releaseEscrow(paymentId);

            //ensure that nothing has been released
            const payment = convertPayment(await escrow.getPayment(paymentId));
            verifyPayment(payment, {
                id: paymentId,
                payer: payer1.address,
                receiver: receiver1.address,
                amount,
                amountRefunded: 0,
                payerReleased: true,
                receiverReleased: true,
                released: true,
                currency: ethers.ZeroAddress,
            });

            //check the balance
            const finalContractBalance = await getBalance(escrow.target);
            const finalReceiverBalance = await getBalance(receiver1.address);
            expect(finalContractBalance).to.equal(
                newContractBalance - BigInt(amount)
            );
        });

        it('can release a token payment with both approvals', async function () {
            const initialContractBalance = await getBalance(
                escrow.target,
                true
            );
            const initialReceiverBalance = await getBalance(
                receiver1.address,
                true
            );
            const amount = 10000000;

            //place the payment
            const paymentId = ethers.keccak256('0x01');
            await placePayment(
                paymentId,
                payer1,
                receiver1.address,
                amount,
                true
            );

            //check the balance
            const newContractBalance = await getBalance(escrow.target, true);
            const newReceiverBalance = await getBalance(
                receiver1.address,
                true
            );
            expect(newContractBalance).to.equal(
                initialContractBalance + BigInt(amount)
            );
            expect(newReceiverBalance).to.equal(initialReceiverBalance);

            //try to release the payment
            await escrow.connect(receiver1).releaseEscrow(paymentId);
            await escrow.connect(payer1).releaseEscrow(paymentId);

            //ensure that nothing has been released
            const payment = convertPayment(await escrow.getPayment(paymentId));
            verifyPayment(payment, {
                id: paymentId,
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
            const finalContractBalance = await getBalance(escrow.target, true);
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

        it('arbiter can release a payment on behalf of payer', async function () {
            const initialContractBalance = await getBalance(
                escrow.target,
                true
            );
            const initialReceiverBalance = await getBalance(
                receiver1.address,
                true
            );
            const amount = 10000000;

            //place the payment
            const paymentId = ethers.keccak256('0x01');
            await testToken.connect(payer1).approve(escrow.target, amount);
            await placePayment(
                paymentId,
                payer1,
                receiver1.address,
                amount,
                true
            );

            //check the balance
            const newContractBalance = await getBalance(escrow.target, true);
            const newReceiverBalance = await getBalance(
                receiver1.address,
                true
            );
            expect(newContractBalance).to.equal(
                initialContractBalance + BigInt(amount)
            );
            expect(newReceiverBalance).to.equal(initialReceiverBalance);

            //try to release the payment
            await escrow.connect(receiver1).releaseEscrow(paymentId);
            await escrow.connect(arbiter).releaseEscrow(paymentId);

            //ensure that nothing has been released
            const payment = convertPayment(await escrow.getPayment(paymentId));
            verifyPayment(payment, {
                id: paymentId,
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
            const finalContractBalance = await getBalance(escrow.target, true);
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

        it('not possible to release a payment for which one is not a party', async function () {
            const initialContractBalance = await getBalance(
                escrow.target,
                true
            );
            const amount = 10000000;

            //place the payment
            const paymentId = ethers.keccak256('0x01');
            await placePayment(
                paymentId,
                payer1,
                receiver1.address,
                amount,
                true
            );

            //check the balance
            const newContractBalance = await getBalance(escrow.target, true);
            expect(newContractBalance).to.equal(
                initialContractBalance + BigInt(amount)
            );

            //try to release the payment, but with an unauthorized account
            await expect(
                escrow.connect(nonOwner).releaseEscrow(paymentId)
            ).to.be.revertedWith('Unauthorized');

            //ensure that nothing has been released
            const payment = convertPayment(await escrow.getPayment(paymentId));
            verifyPayment(payment, {
                id: paymentId,
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
            const finalContractBalance = await getBalance(escrow.target, true);
            expect(finalContractBalance).to.equal(newContractBalance);
        });

        it('not possible to release a payment twice', async function () {
            const initialContractBalance = await getBalance(
                escrow.target,
                true
            );
            const initialReceiverBalance = await getBalance(
                receiver1.address,
                true
            );
            const amount = 10000000;

            //place the payment
            const paymentId = ethers.keccak256('0x01');
            await placePayment(
                paymentId,
                payer1,
                receiver1.address,
                amount,
                true
            );

            //check the balance
            const newContractBalance = await getBalance(escrow.target, true);
            const newReceiverBalance = await getBalance(
                receiver1.address,
                true
            );
            expect(newContractBalance).to.equal(
                initialContractBalance + BigInt(amount)
            );
            expect(newReceiverBalance).to.equal(initialReceiverBalance);

            //try to release the payment
            await escrow.connect(receiver1).releaseEscrow(paymentId);
            await escrow.connect(payer1).releaseEscrow(paymentId);

            //ensure that nothing has been released
            const payment = convertPayment(await escrow.getPayment(paymentId));
            verifyPayment(payment, {
                id: paymentId,
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
            await escrow.connect(receiver1).releaseEscrow(paymentId);
            await escrow.connect(payer1).releaseEscrow(paymentId);

            //check the balance
            const finalContractBalance = await getBalance(escrow.target, true);
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

    describe('Refund Payments', function () {
        async function refundTest(
            amount: number,
            refundAmount: number,
            payerAccount: HardhatEthersSigner,
            receiverAccount: HardhatEthersSigner,
            refunderAccount: HardhatEthersSigner
        ): Promise<string> {
            const initialContractBalance = await getBalance(
                escrow.target,
                true
            );
            const initialPayerBalance = await getBalance(
                payerAccount.address,
                true
            );

            //place the payment
            const paymentId = ethers.keccak256('0x01');
            await placePayment(
                paymentId,
                payerAccount,
                receiverAccount.address,
                amount,
                true
            );

            //partially refund the payment
            await escrow
                .connect(refunderAccount)
                .refundPayment(paymentId, refundAmount);

            //get & check the payment - was it refunded?
            const payment = convertPayment(await escrow.getPayment(paymentId));
            expect(payment.amountRefunded).to.equal(refundAmount);
            expect(payment.amount).to.equal(amount);

            //check the balances
            const finalContractBalance = await getBalance(escrow.target, true);
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

            return paymentId;
        }

        it('arbiter can cause a partial refund', async function () {
            const amount = 1000000;
            await refundTest(amount, amount / 5, payer1, receiver1, arbiter);
        });

        it('receiver can cause a partial refund', async function () {
            const amount = 1000000;
            await refundTest(amount, amount / 5, payer1, receiver1, receiver1);
        });

        it('arbiter can cause a full refund', async function () {
            const amount = 1000000;
            await refundTest(amount, amount, payer1, receiver1, arbiter);
        });

        it('receiver can cause a full refund', async function () {
            const amount = 1000000;
            await refundTest(amount, amount, payer1, receiver1, receiver1);
        });

        it('can do multiple partial refunds', async function () {
            const amount = 1000000;
            const refundAmount = amount / 5;
            const initialContractBalance = await getBalance(
                escrow.target,
                true
            );
            const initialPayerBalance = await getBalance(payer1.address, true);

            //initial refund
            const paymentId = await refundTest(
                amount,
                refundAmount,
                payer1,
                receiver1,
                receiver1
            );

            //partially refund the payment
            await escrow.connect(arbiter).refundPayment(paymentId, amount / 5);

            //get & check the payment - was it refunded?
            const payment = convertPayment(await escrow.getPayment(paymentId));
            expect(payment.amountRefunded).to.equal(refundAmount * 2);
            expect(payment.amount).to.equal(amount);

            //check the balances
            const finalContractBalance = await getBalance(escrow.target, true);
            const finalPayerBalance = await getBalance(payer1.address, true);

            expect(finalContractBalance).to.equal(
                initialContractBalance + BigInt(amount - refundAmount * 2)
            );
            expect(finalPayerBalance).to.equal(
                initialPayerBalance - BigInt(amount - refundAmount * 2)
            );
        });

        it('not possible to refund a payment to which one is not a party', async function () {
            const amount = 100000000;

            //place the payment
            const paymentId = ethers.keccak256('0x01');
            await placePayment(
                paymentId,
                payer1,
                receiver1.address,
                amount,
                true
            );

            //attempt to refund non-authorized
            await expect(
                escrow.connect(payer1).refundPayment(paymentId, amount)
            ).to.be.reverted;

            //attempt to refund authorized
            await expect(
                escrow.connect(arbiter).refundPayment(paymentId, amount)
            ).to.not.be.reverted;
        });

        it('not possible to refund more than the payment amount', async function () {
            const amount = 100000000;

            //place the payment
            const paymentId = ethers.keccak256('0x01');
            await placePayment(
                paymentId,
                payer1,
                receiver1.address,
                amount,
                true
            );

            //attempt to refund more than one should
            await expect(
                escrow.connect(arbiter).refundPayment(paymentId, amount + 1)
            ).to.be.revertedWith('AmountExceeded');

            //attempt to refund normal amount
            await expect(
                escrow.connect(arbiter).refundPayment(paymentId, amount)
            ).to.not.be.reverted;
        });

        it('not possible to refund more than the payment amount, using multiple refunds', async function () {
            const amount = 100000000;

            //place the payment
            const paymentId = ethers.keccak256('0x01');
            await placePayment(
                paymentId,
                payer1,
                receiver1.address,
                amount,
                true
            );

            //refunds that should be allowed
            await expect(
                escrow.connect(arbiter).refundPayment(paymentId, amount - 2)
            ).to.not.be.reverted;
            await expect(escrow.connect(arbiter).refundPayment(paymentId, 1)).to
                .not.be.reverted;

            //attempt to refund more than one should
            await expect(
                escrow.connect(arbiter).refundPayment(paymentId, 100)
            ).to.be.revertedWith('AmountExceeded');

            //attempt to refund normal amount
            await expect(escrow.connect(arbiter).refundPayment(paymentId, 1)).to
                .not.be.reverted;
        });
    });

    describe('Fee Amounts', function () {
        const feeBps = 200;

        this.beforeEach(async () => {
            await systemSettings.connect(dao).setFeeBps(feeBps);
        });

        it('fees are calculated correctly', async function () {
            const paymentId = ethers.keccak256('0x01');
            const amount = 10000000;
            const receiverInitialAmount = await getBalance(
                receiver1.address,
                true
            );

            //ensure that dao balance at start is 0
            expect(await getBalance(vaultAddress, true)).to.equal(0);

            //place a payment
            await placePayment(
                paymentId,
                payer1,
                receiver1.address,
                amount,
                true
            );

            //release the payment from escrow
            await escrow.connect(payer1).releaseEscrow(paymentId);
            await escrow.connect(receiver1).releaseEscrow(paymentId);

            //fee should be in the vault
            const feeAmount = amount * (feeBps / 10000);
            expect(await getBalance(vaultAddress, true)).to.equal(feeAmount);

            //remainder amount should have gone to the receiver
            expect(await getBalance(receiver1.address, true)).to.equal(
                receiverInitialAmount + BigInt(amount - feeAmount)
            );
        });

        it('fee can be 0%', async function () {
            const paymentId = ethers.keccak256('0x01');
            const amount = 10000000;
            const receiverInitialAmount = await getBalance(
                receiver1.address,
                true
            );

            //set fee to 0
            await systemSettings.connect(dao).setFeeBps(0);

            //ensure that dao balance at start is 0
            expect(await getBalance(vaultAddress, true)).to.equal(0);

            //place a payment
            await placePayment(
                paymentId,
                payer1,
                receiver1.address,
                amount,
                true
            );

            //release the payment from escrow
            await escrow.connect(payer1).releaseEscrow(paymentId);
            await escrow.connect(receiver1).releaseEscrow(paymentId);

            //no fees should have gone to the vault
            expect(await getBalance(vaultAddress, true)).to.equal(0);

            //full amount should have gone to the receiver
            expect(await getBalance(receiver1.address, true)).to.equal(
                receiverInitialAmount + BigInt(amount)
            );
        });

        it('fee can be 100%', async function () {
            const paymentId = ethers.keccak256('0x01');
            const amount = 10000000;
            const receiverInitialAmount = await getBalance(
                receiver1.address,
                true
            );

            //set fee to 0
            await systemSettings.connect(dao).setFeeBps(10000);

            //ensure that dao balance at start is 0
            expect(await getBalance(vaultAddress, true)).to.equal(0);

            //place a payment
            await placePayment(
                paymentId,
                payer1,
                receiver1.address,
                amount,
                true
            );

            //release the payment from escrow
            await escrow.connect(payer1).releaseEscrow(paymentId);
            await escrow.connect(receiver1).releaseEscrow(paymentId);

            //full should have gone to the vault
            expect(await getBalance(vaultAddress, true)).to.equal(amount);

            //no amount should have gone to the receiver
            expect(await getBalance(receiver1.address, true)).to.equal(
                receiverInitialAmount
            );
        });

        it('fee is calculated from amount remaining after refund', async function () {
            const paymentId = ethers.keccak256('0x01');
            const amount = 10000000;
            const refundAmount = 40000;
            const receiverInitialAmount = await getBalance(
                receiver1.address,
                true
            );

            //ensure that dao balance at start is 0
            expect(await getBalance(vaultAddress, true)).to.equal(0);

            //place a payment
            await placePayment(
                paymentId,
                payer1,
                receiver1.address,
                amount,
                true
            );

            //refund a small amount
            await escrow
                .connect(arbiter)
                .refundPayment(paymentId, refundAmount);

            //release the payment from escrow
            await escrow.connect(payer1).releaseEscrow(paymentId);
            await escrow.connect(receiver1).releaseEscrow(paymentId);

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
            const paymentId = ethers.keccak256('0x01');
            const amount = 10000000;
            const refundAmount = amount;
            const receiverInitialAmount = await getBalance(
                receiver1.address,
                true
            );

            //ensure that dao balance at start is 0
            expect(await getBalance(vaultAddress, true)).to.equal(0);

            //place a payment
            await placePayment(
                paymentId,
                payer1,
                receiver1.address,
                amount,
                true
            );

            //refund all
            await escrow
                .connect(arbiter)
                .refundPayment(paymentId, refundAmount);

            //release the payment from escrow
            await escrow.connect(payer1).releaseEscrow(paymentId);
            await escrow.connect(receiver1).releaseEscrow(paymentId);

            //no fee should be in the vault
            expect(await getBalance(vaultAddress, true)).to.equal(0);

            //none should have gone to receiver
            expect(await getBalance(receiver1.address, true)).to.equal(
                receiverInitialAmount
            );
        });

        it('no fee is taken if fee rate is > 100%', async function () {
            const paymentId = ethers.keccak256('0x01');
            const amount = 10000000;
            const refundAmount = amount;
            const receiverInitialAmount = await getBalance(
                receiver1.address,
                true
            );

            //set fee to > 100%
            await systemSettings.connect(dao).setFeeBps(20101);

            //ensure that dao balance at start is 0
            expect(await getBalance(vaultAddress, true)).to.equal(0);

            //place a payment
            await placePayment(
                paymentId,
                payer1,
                receiver1.address,
                amount,
                true
            );

            //release the payment from escrow
            await escrow.connect(payer1).releaseEscrow(paymentId);
            await escrow.connect(receiver1).releaseEscrow(paymentId);

            //no fee should be in the vault
            expect(await getBalance(vaultAddress, true)).to.equal(0);

            //all should have gone to receiver
            expect(await getBalance(receiver1.address, true)).to.equal(
                receiverInitialAmount + BigInt(amount)
            );
        });
    });

    describe('Edge Cases', function () {
        it('payer and receiver are the same', async function () {
            const initialPayerBalance = await getBalance(payer1.address, true);
            const amount = 10000000;

            //place the payment
            const paymentId = ethers.keccak256('0x01');
            await placePayment(paymentId, payer1, payer1.address, amount, true);

            //check the balance
            const newPayerBalance = await getBalance(payer1.address, true);
            expect(newPayerBalance).to.equal(
                initialPayerBalance - BigInt(amount)
            );

            //try to release the payment
            await escrow.connect(payer1).releaseEscrow(paymentId);
            await escrow.connect(payer1).releaseEscrow(paymentId);

            //ensure that nothing has been released
            const payment = convertPayment(await escrow.getPayment(paymentId));
            verifyPayment(payment, {
                id: paymentId,
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

    //TODO: finish these tests
    describe('Multicall', function () {
        it('can place payments to different escrows', async function () {
            const amount1 = 10000;
            const amount2 = 22500;
            const amount3 = 32500;
            const id1 = ethers.keccak256('0x01');
            const id2 = ethers.keccak256('0x02');
            const id3 = ethers.keccak256('0x03');

            await testToken.connect(payer1).approve(multicall.target, amount3);

            await multicall.connect(payer1).multipay(
                [
                    {
                        contractAddress: escrow1.target,
                        currency: ethers.ZeroAddress,
                        receiver: receiver1.address,
                        payer: payer1.address,
                        amount: amount1,
                        id: id1,
                    },
                    {
                        contractAddress: escrow2.target,
                        currency: ethers.ZeroAddress,
                        receiver: receiver1.address,
                        payer: payer1.address,
                        amount: amount2,
                        id: id2,
                    },
                    {
                        contractAddress: escrow3.target,
                        currency: testToken.target,
                        receiver: receiver1.address,
                        payer: payer1.address,
                        amount: amount3,
                        id: id3,
                    },
                ],
                { value: amount1 + amount2 }
            );

            //multicall should retain nothing
            expect(await getBalance(multicall.target, true)).to.equal(0);
            expect(await getBalance(multicall.target, false)).to.equal(0);

            //escrows should contain what they contain
            expect(await getBalance(escrow1.target, true)).to.equal(0);
            expect(await getBalance(escrow1.target, false)).to.equal(amount1);
            expect(await getBalance(escrow2.target, true)).to.equal(0);
            expect(await getBalance(escrow2.target, false)).to.equal(amount2);
            expect(await getBalance(escrow3.target, true)).to.equal(amount3);
            expect(await getBalance(escrow3.target, false)).to.equal(0);
        });

        it('can place multiple payments to the same escrow', async function () {
            const amount1 = 10000;
            const amount2 = 22500;
            const amount3 = 32500;
            const id1 = ethers.keccak256('0x01');
            const id2 = ethers.keccak256('0x02');
            const id3 = ethers.keccak256('0x03');

            await testToken.connect(payer1).approve(multicall.target, amount3);

            await multicall.connect(payer1).multipay(
                [
                    {
                        contractAddress: escrow1.target,
                        currency: ethers.ZeroAddress,
                        receiver: receiver1.address,
                        payer: payer1.address,
                        amount: amount1,
                        id: id1,
                    },
                    {
                        contractAddress: escrow1.target,
                        currency: ethers.ZeroAddress,
                        receiver: receiver1.address,
                        payer: payer1.address,
                        amount: amount2,
                        id: id2,
                    },
                    {
                        contractAddress: escrow1.target,
                        currency: testToken.target,
                        receiver: receiver1.address,
                        payer: payer1.address,
                        amount: amount3,
                        id: id3,
                    },
                ],
                { value: amount1 + amount2 }
            );

            //multicall should retain nothing
            expect(await getBalance(multicall.target, true)).to.equal(0);
            expect(await getBalance(multicall.target, false)).to.equal(0);

            //escrows should contain what they contain
            expect(await getBalance(escrow1.target, true)).to.equal(amount3);
            expect(await getBalance(escrow1.target, false)).to.equal(
                amount1 + amount2
            );
        });

        it('multicall to invalid escrow', async function () {
            const amount = 10000;
            const id = ethers.keccak256('0x01');
            await expect(
                multicall.connect(payer1).multipay(
                    [
                        {
                            contractAddress: multicall.target,
                            currency: ethers.ZeroAddress,
                            receiver: receiver1.address,
                            payer: payer1.address,
                            amount,
                            id,
                        },
                    ],
                    { value: amount }
                )
            ).to.be.reverted;

            await testToken.connect(payer1).approve(multicall.target, amount);

            await expect(
                multicall.connect(payer1).multipay([
                    {
                        contractAddress: multicall.target,
                        currency: testToken.target,
                        receiver: receiver1.address,
                        payer: payer1.address,
                        amount,
                        id,
                    },
                ])
            ).to.be.reverted;
        });

        it.skip('multicall with insufficient native amount', async function () {
            const amount = '100000000000000000000000';
            const id = ethers.keccak256('0x01');
            await expect(
                multicall.connect(payer1).multipay(
                    [
                        {
                            contractAddress: escrow.target,
                            currency: ethers.ZeroAddress,
                            receiver: receiver1.address,
                            payer: payer1.address,
                            amount,
                            id,
                        },
                    ],
                    { value: amount }
                )
            ).to.be.reverted;
        });

        it('multicall with insufficient token amount', async function () {
            const amount = 10000;
            const id = ethers.keccak256('0x01');
            await expect(
                multicall.connect(payer1).multipay([
                    {
                        contractAddress: escrow.target,
                        currency: testToken.target,
                        receiver: receiver1.address,
                        payer: payer1.address,
                        amount,
                        id,
                    },
                ])
            ).to.be.reverted;
        });

        it('multicall to valid escrow, invalid receiver', async function () {});
    });
});
