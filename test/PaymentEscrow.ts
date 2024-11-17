import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';

//TODO: test the coverage

describe('PaymentEscrow', function () {
    let securityContext: any;
    let escrow: any;
    let testToken: any;
    let escrowSettings: any;
    let admin: HardhatEthersSigner;
    let nonOwner: HardhatEthersSigner;
    let payer1: HardhatEthersSigner;
    let payer2: HardhatEthersSigner;
    let receiver1: HardhatEthersSigner;
    let receiver2: HardhatEthersSigner;
    let vaultAddress: HardhatEthersSigner;

    const ARBITER_ROLE = hre.ethers.keccak256(
        hre.ethers.encodeBytes32String('ARBITER_ROLE')
    );

    this.beforeEach(async () => {
        const [a1, a2, a3, a4, a5, a6, a7] = await hre.ethers.getSigners();
        admin = a1;
        nonOwner = a2;
        vaultAddress = a3;
        payer1 = a4;
        payer2 = a5;
        receiver1 = a6;
        receiver2 = a7;

        //deploy security context
        const SecurityContextFactory =
            await hre.ethers.getContractFactory('SecurityContext');
        securityContext = await SecurityContextFactory.deploy(admin.address);

        //deploy test token
        const TestTokenFactory =
            await hre.ethers.getContractFactory('TestToken');
        testToken = await TestTokenFactory.deploy('XYZ', 'ZYX');

        //deploy settings
        const EscrowSettingsFactory =
            await hre.ethers.getContractFactory('EscrowSettings');
        escrowSettings = await EscrowSettingsFactory.deploy(
            securityContext.target,
            vaultAddress,
            100
        );

        //grant roles
        const PaymentEscrowFactory =
            await hre.ethers.getContractFactory('PaymentEscrow');
        escrow = await PaymentEscrowFactory.deploy(
            securityContext.target,
            escrowSettings.target
        );
        await securityContext
            .connect(admin)
            .grantRole(ARBITER_ROLE, vaultAddress);

        await securityContext
            .connect(admin)
            .grantRole(ARBITER_ROLE, admin.address);

        //grant token
        await testToken.mint(nonOwner, 10000000000);
        await testToken.mint(payer1, 10000000000);
        await testToken.mint(payer2, 10000000000);
    });

    describe('Deployment', function () {
        it('Should set the right arbiter role', async function () {
            expect(await securityContext.hasRole(ARBITER_ROLE, admin.address))
                .to.be.true;
            expect(
                await securityContext.hasRole(ARBITER_ROLE, nonOwner.address)
            ).to.be.false;
            expect(await securityContext.hasRole(ARBITER_ROLE, vaultAddress)).to
                .be.true;
        });
    });

    /*
    PLACE PAYMENTS
    #can place a single payment
        #TOKEN: 
        - payment is logged in contract with right values 
        - amount leaves payer 
        - amount accrues in contract
        #NATIVE:
        - payment is logged in contract with right values 
        - amount leaves payer 
        - amount accrues in contract
    #can place multiple payments
        #TOKEN: 
        - payment is logged in contract with right values 
        - amount leaves payer 
        - amount accrues in contract
        #NATIVE:
        - payment is logged in contract with right values 
        - amount leaves payer 
        - amount accrues in contract
    can place mixed token & native payments
    paid amounts accrue in contract
        NATIVE 
        - multiple payments, balance accrues 
        TOKEN
        - multiple payments, balance accrues 
    cannot place order without correct amount 
        NATIVE 
        - with 0 amount
        - without correct amount
        TOKEN
        - without having approved any
        - without having approved correct amount 
    cannot place new order with same payment id

    RELEASE PAYMENTS
    cannot release a payment with no approvals
    cannot release a payment with only payer approval
    cannot release a payment with only receiver approval
    can release a payment with both approvals
    arbiter can release a payment on behalf of payer
    not possible to release a payment for which one is not a party
    not possible to release a payment twice

    REFUNDS
    arbiter can cause a partial refund
    arbiter can cause a full refund
    receiver can cause a partial refund
    receiver can cause a full refund
    not possible to refund a payment to which one is not a party

    REFUND & RELEASE
    fully refunded payment cannot be released
    partially refunded payment can be only partially released

    VAULT ADDRESS 
    fees go to the correct address
    vault address cannot be zero 

    FEE AMOUNTS 
    fees are calculated correctly 
    fee can be zero 

    EDGE CASES 
    payer & receiver are the same 
    */

    async function getBalance(address: any, isToken = false) {
        return isToken
            ? await await testToken.balanceOf(address)
            : await admin.provider.getBalance(address);
    }

    interface IPayment {
        id: any;
        payer: any;
        receiver: any;
        amount: any;
        amountRefunded: any;
        payerReleased: any;
        receiverReleased: any;
        released: any;
        currency: any;
    }

    function convertPayment(rawData: any[]): IPayment {
        return {
            id: rawData[0],
            payer: rawData[1],
            receiver: rawData[2],
            amount: rawData[3],
            amountRefunded: rawData[4],
            payerReleased: rawData[5],
            receiverReleased: rawData[6],
            released: rawData[7],
            currency: rawData[8],
        };
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
            await escrow.connect(payer1).placeMultiPayments(
                [
                    {
                        currency: ethers.ZeroAddress,
                        payments: [
                            {
                                id: paymentId,
                                receiver: receiver1.address,
                                payer: payer1.address,
                                amount,
                            },
                        ],
                    },
                ],
                { value: amount }
            );

            //payment is logged in contract with right values
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
            await testToken.connect(payer1).approve(escrow.target, amount);
            await escrow.connect(payer1).placeMultiPayments([
                {
                    currency: testToken.target,
                    payments: [
                        {
                            id: paymentId,
                            receiver: receiver1.address,
                            payer: payer1.address,
                            amount,
                        },
                    ],
                },
            ]);

            //payment is logged in contract with right values
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

        it('can place multiple native payments', async function () {
            const initialContractBalance = await getBalance(escrow.target);
            const initialPayerBalance = await getBalance(payer1.address);
            const amount1 = 10000000;
            const amount2 = 24000000;

            //place the payment
            const paymentId1 = ethers.keccak256('0x01');
            const paymentId2 = ethers.keccak256('0x02');
            await escrow.connect(payer1).placeMultiPayments(
                [
                    {
                        currency: ethers.ZeroAddress,
                        payments: [
                            {
                                id: paymentId1,
                                receiver: receiver1.address,
                                payer: payer1.address,
                                amount: amount1,
                            },
                            {
                                id: paymentId2,
                                receiver: receiver2.address,
                                payer: payer1.address,
                                amount: amount2,
                            },
                        ],
                    },
                ],
                { value: amount1 + amount2 }
            );

            //payment is logged in contract with right values
            const payment1 = convertPayment(
                await escrow.getPayment(paymentId1)
            );
            const payment2 = convertPayment(
                await escrow.getPayment(paymentId2)
            );

            verifyPayment(payment1, {
                id: paymentId1,
                payer: payer1.address,
                receiver: receiver1.address,
                amount: amount1,
                amountRefunded: 0,
                payerReleased: false,
                receiverReleased: false,
                released: false,
                currency: ethers.ZeroAddress,
            });
            verifyPayment(payment2, {
                id: paymentId2,
                payer: payer1.address,
                receiver: receiver2.address,
                amount: amount2,
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
                initialPayerBalance - BigInt(amount1 + amount2)
            );

            //amount accrues in contract
            expect(newContractBalance).to.equal(
                initialContractBalance + BigInt(amount1 + amount2)
            );
        });

        it('can place multiple token payments', async function () {
            const initialContractBalance = await getBalance(
                escrow.target,
                true
            );
            const initialPayerBalance = await getBalance(payer1.address, true);
            const amount1 = 10000000;
            const amount2 = 24000000;

            //place the payment
            const paymentId1 = ethers.keccak256('0x01');
            const paymentId2 = ethers.keccak256('0x02');
            await testToken
                .connect(payer1)
                .approve(escrow.target, amount1 + amount2);
            await escrow.connect(payer1).placeMultiPayments(
                [
                    {
                        currency: testToken.target,
                        payments: [
                            {
                                id: paymentId1,
                                receiver: receiver1.address,
                                payer: payer1.address,
                                amount: amount1,
                            },
                            {
                                id: paymentId2,
                                receiver: receiver2.address,
                                payer: payer1.address,
                                amount: amount2,
                            },
                        ],
                    },
                ],
                { value: amount1 + amount2 }
            );

            //payment is logged in contract with right values
            const payment1 = convertPayment(
                await escrow.getPayment(paymentId1)
            );
            const payment2 = convertPayment(
                await escrow.getPayment(paymentId2)
            );

            verifyPayment(payment1, {
                id: paymentId1,
                payer: payer1.address,
                receiver: receiver1.address,
                amount: amount1,
                amountRefunded: 0,
                payerReleased: false,
                receiverReleased: false,
                released: false,
                currency: testToken.target,
            });
            verifyPayment(payment2, {
                id: paymentId2,
                payer: payer1.address,
                receiver: receiver2.address,
                amount: amount2,
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
                initialPayerBalance - BigInt(amount1 + amount2)
            );

            //amount accrues in contract
            expect(newContractBalance).to.equal(
                initialContractBalance + BigInt(amount1 + amount2)
            );
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
            await testToken.connect(payer1).approve(escrow.target, amount);
            await escrow.connect(payer1).placeMultiPayments(
                [
                    {
                        currency: testToken.target,
                        payments: [
                            {
                                id: paymentId,
                                receiver: receiver1.address,
                                payer: payer1.address,
                                amount,
                            },
                        ],
                    },
                ],
                { value: amount }
            );

            //check the balance
            const newContractBalance = await getBalance(escrow.target);
            expect(newContractBalance).to.equal(
                initialContractBalance + BigInt(amount)
            );

            //try to release the payment
            await expect(escrow.releaseEscrow(paymentId)).to.be.revertedWith(
                'Unauthorized'
            );

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

        it('cannot release a payment with only payer approval', async function () {
            const initialContractBalance = await getBalance(escrow.target);
            const amount = 10000000;

            //place the payment
            const paymentId = ethers.keccak256('0x01');
            await escrow.connect(payer1).placeMultiPayments(
                [
                    {
                        currency: ethers.ZeroAddress,
                        payments: [
                            {
                                id: paymentId,
                                receiver: receiver1.address,
                                payer: payer1.address,
                                amount,
                            },
                        ],
                    },
                ],
                { value: amount }
            );

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
            await escrow.connect(payer1).placeMultiPayments(
                [
                    {
                        currency: ethers.ZeroAddress,
                        payments: [
                            {
                                id: paymentId,
                                receiver: receiver1.address,
                                payer: payer1.address,
                                amount,
                            },
                        ],
                    },
                ],
                { value: amount }
            );

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

        it('can release a payment with both approvals', async function () {
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
            await escrow.connect(payer1).placeMultiPayments(
                [
                    {
                        currency: testToken.target,
                        payments: [
                            {
                                id: paymentId,
                                receiver: receiver1.address,
                                payer: payer1.address,
                                amount,
                            },
                        ],
                    },
                ],
                { value: amount }
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

        it.skip('arbiter can release a payment on behalf of payer', async function () {
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
            await escrow.connect(payer1).placeMultiPayments(
                [
                    {
                        currency: testToken.target,
                        payments: [
                            {
                                id: paymentId,
                                receiver: receiver1.address,
                                payer: payer1.address,
                                amount,
                            },
                        ],
                    },
                ],
                { value: amount }
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
            await escrow.connect(admin).releaseEscrowOnBehalfOfPayer(paymentId);

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
            await testToken.connect(payer1).approve(escrow.target, amount);
            await escrow.connect(payer1).placeMultiPayments(
                [
                    {
                        currency: testToken.target,
                        payments: [
                            {
                                id: paymentId,
                                receiver: receiver1.address,
                                payer: payer1.address,
                                amount,
                            },
                        ],
                    },
                ],
                { value: amount }
            );

            //check the balance
            const newContractBalance = await getBalance(escrow.target);
            expect(newContractBalance).to.equal(
                initialContractBalance + BigInt(amount)
            );

            //try to release the payment
            await expect(escrow.releaseEscrow(paymentId)).to.be.revertedWith(
                'Unauthorized'
            );

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
            await testToken.connect(payer1).approve(escrow.target, amount);
            await escrow.connect(payer1).placeMultiPayments(
                [
                    {
                        currency: testToken.target,
                        payments: [
                            {
                                id: paymentId,
                                receiver: receiver1.address,
                                payer: payer1.address,
                                amount,
                            },
                        ],
                    },
                ],
                { value: amount }
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
        it('arbiter can cause a partial refund', async function () {});
        //arbiter can cause a full refund
        //receiver can cause a partial refund
        it('receiver can cause a full refund', async function () {});
        //not possible to refund a payment to which one is not a party
    });
});
