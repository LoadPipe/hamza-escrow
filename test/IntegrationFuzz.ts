import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { BigNumberish, keccak256 } from 'ethers';
import { IPayment, convertPayment } from './util';
import { sign } from 'crypto';

describe('PaymentEscrow', function () {
    let securityContext: any;
    let escrow: any;
    let testToken: any;
    let systemSettings: any;
    let admin: HardhatEthersSigner;
    let payers: HardhatEthersSigner[];
    let receivers: HardhatEthersSigner[];
    let vaultAddress: HardhatEthersSigner;
    let arbiter: HardhatEthersSigner;
    let dao: HardhatEthersSigner;

    function generatePaymentId(): string {
        let result = '';
        const characters =
            'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
        const charactersLength = characters.length;
        let n = 0;
        while (n < length) {
            result += characters.charAt(
                Math.floor(Math.random() * charactersLength)
            );
            n += 1;
        }
        return result;
    }

    function randomWholeNum(min: number, max: number) {
        return Math.floor(Math.random() * (max - min)) + min;
    }

    function getIndexList(count: number): number[] {
        const output: number[] = [];
        for (let n = 0; n < count; n++) {
            output[n] = n;
        }
        return output;
    }

    function pickRandomAgents(
        signers: HardhatEthersSigner[]
    ): HardhatEthersSigner[] {
        const count: number = randomWholeNum(1, payers.length);
        const output: HardhatEthersSigner[] = [];
        const indices = getIndexList(payers.length);
        for (let n = 0; n < count; n++) {
            const randIndex: number = randomWholeNum(0, indices.length);
            const index = indices[randIndex];
            output.push(signers[index]);
            indices.splice(index, 1);
        }
        return output;
    }

    function pickRandomPayers(): HardhatEthersSigner[] {
        return pickRandomAgents(payers);
    }

    function pickRandomReceivers(): HardhatEthersSigner[] {
        return pickRandomAgents(receivers);
    }

    async function playRound() {
        const payers = pickRandomPayers();
        const receivers = pickRandomReceivers();

        for (let n = 0; n < payers.length; n++) {
            //match random payer to random receiver
            await makePurchases(payers[n], receivers[n], testToken.target);
        }
    }

    async function makePurchases(
        payer: HardhatEthersSigner,
        receiver: HardhatEthersSigner,
        currency: any
    ): Promise<string> {
        const amount: number = randomWholeNum(1, getBalance(payer));
        const paymentId: string = generatePaymentId(); 
        
    }

    const ARBITER_ROLE =
        '0xbb08418a67729a078f87bbc8d02a770929bb68f5bfdf134ae2ead6ed38e2f4ae';

    const DAO_ROLE =
        '0x3b5d4cc60d3ec3516ee8ae083bd60934f6eb2a6c54b1229985c41bfb092b2603';

    this.beforeEach(async () => {
        const [a1, a2, a3, a4, a5, a6, a7, a8, a9, a10] =
            await hre.ethers.getSigners();
        admin = a1;
        vaultAddress = a2;
        arbiter = a3;
        dao = a4;
        payers = [a5, a6, a7];
        receivers = [a8, a9, a10];

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

        //grant roles
        const PaymentEscrowFactory =
            await hre.ethers.getContractFactory('PaymentEscrow');
        escrow = await PaymentEscrowFactory.deploy(
            securityContext.target,
            systemSettings.target
        );
        await securityContext
            .connect(admin)
            .grantRole(ARBITER_ROLE, vaultAddress);

        await securityContext
            .connect(admin)
            .grantRole(ARBITER_ROLE, arbiter.address);

        await securityContext.connect(admin).grantRole(DAO_ROLE, dao.address);

        //grant token
        for (let n = 0; n < payers.length; n++) {
            await testToken.mint(payers[n], 10000000000);
        }
    });

    describe('Integration Fuzz', function () {
        it('start', async function () {});
    });
});
