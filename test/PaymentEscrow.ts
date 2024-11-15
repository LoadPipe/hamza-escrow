import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';

describe('PaymentEscrow', function () {
    let securityContext: any;
    let escrow: any;
    let testToken: any;
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
        receiver1 = a4;
        receiver2 = a4;

        //deploy security context
        const SecurityContextFactory =
            await hre.ethers.getContractFactory('SecurityContext');
        securityContext = await SecurityContextFactory.deploy(admin.address);

        //deploy test token
        const TestTokenFactory =
            await hre.ethers.getContractFactory('TestToken');
        testToken = await TestTokenFactory.deploy('XYZ', 'ZYX');

        //grant roles
        const PaymentEscrowFactory =
            await hre.ethers.getContractFactory('PaymentEscrow');
        escrow = await PaymentEscrowFactory.deploy(
            securityContext.target,
            vaultAddress
        );
        await securityContext
            .connect(admin)
            .grantRole(ARBITER_ROLE, vaultAddress);

        //grant token
        await testToken.mint(a2, 100000000);
    });

    describe('Deployment', function () {
        it('Should set the right arbiter role', async function () {
            expect(await securityContext.hasRole(ARBITER_ROLE, admin.address))
                .to.be.false;
            expect(
                await securityContext.hasRole(ARBITER_ROLE, nonOwner.address)
            ).to.be.false;
            expect(await securityContext.hasRole(ARBITER_ROLE, vaultAddress)).to
                .be.true;
        });
    });

    /*
    PLACE PAYMENTS
    can place a single payment
        TOKEN: 
        - payment is logged in contract with right values 
        - amount leaves payer 
        - amount accrues in contract
        NATIVE:
        - payment is logged in contract with right values 
        - amount leaves payer 
        - amount accrues in contract
    can place multiple payments
        TOKEN: 
        - payment is logged in contract with right values 
        - amount leaves payer 
        - amount accrues in contract
        NATIVE:
        - payment is logged in contract with right values 
        - amount leaves payer 
        - amount accrues in contract
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

    REFUNDS
    arbiter can cause a partial refund
    arbiter can cause a full refund
    receiver can cause a partial refund
    receiver can cause a full refund
    not possible to refund a payment to which one is not a party

    REFUND & RELEASE
    fully refunded payment cannot be released
    partially refunded payment can be only partially released

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
            const payment = await escrow.getPayment(paymentId);
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
        it('can place a single token payment', async function () {});
        it('can place multiple native payments', async function () {});
        it('can place multiple token payments', async function () {});
    });
});
