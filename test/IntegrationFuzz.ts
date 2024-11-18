import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { BigNumberish, keccak256 } from 'ethers';
import { IPayment, convertPayment } from './util';

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

    function playRound() {}

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
