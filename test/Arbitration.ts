import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { BigNumberish, keccak256 } from 'ethers';
import { IEscrow, convertEscrow as convertEscrow } from './util';

describe('Arbitration', function () {
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
        describe('Happy Paths', function () {
            it.skip('can deploy with valid arbitration module', async function () {});
        });
        describe('Exceptions', function () {
            it.skip('cannot deploy with a zero-address arbitration module', async function () {});
            it.skip('cannot deploy with an invalid arbitration module', async function () {});
        });
    });

    describe('Escrow Creation', function () {
        describe('Happy Paths', function () {
            it.skip('can create escrow with valid custom arbitration module', async function () {});
            it.skip('can create escrow with valid default arbitration module', async function () {});
        });
        describe('Exceptions', function () {
            it.skip('cannot create escrow with a zero-address arbitration module', async function () {});
            it.skip('cannot create escrow with an invalid arbitration module', async function () {});
        });
        describe('Events', function () {});
    });

    describe('Proposing Arbitration', function () {
        describe('Happy Paths', function () {
            it.skip('payer can propose arbitration', async function () {});
            it.skip('receiver can propose arbitration', async function () {});
            it.skip('proposal is accepted when votes over threshold', async function () {});
            it.skip('proposal is rejected when votes under threshold', async function () {});
            it.skip('single-arbiter proposal is voted, accepted automatically on proposal creation', async function () {});
        });
        describe('Exceptions', function () {
            it.skip('stranger cannot propose arbitration', async function () {});
            it.skip('arbiter cannot propose arbitration', async function () {});
            it.skip('cannot propose arbitration on invalid escrow id', async function () {});
            it.skip('cannot vote on invalid proposal id', async function () {});
            it.skip('cannot vote on inactive proposal', async function () {});
        });
        describe('Events', function () {
            it.skip('arbitration proposal emits ArbitrationProposed', async function () {});
        });
    });

    describe('Voting on Arbitration', function () {
        describe('Happy Paths', function () {
            it.skip('arbiters can vote yes on arbitration', async function () {});
            it.skip('arbiters can vote no on arbitration', async function () {});
        });
        describe('Exceptions', function () {
            it.skip('payer cannot vote on arbitration', async function () {});
            it.skip('receiver cannot vote on arbitration', async function () {});
            it.skip('stranger cannot vote on arbitration', async function () {});
        });
        describe('Events', function () {
            it.skip('voting emits VoteRecorded', async function () {});
        });
    });

    describe('Cancelling Arbitration', function () {
        describe('Happy Paths', function () {});
        describe('Exceptions', function () {
            it.skip('cannot cancel invalid proposal', async function () {});
            it.skip('cannot cancel inactive proposal', async function () {});
        });
        describe('Events', function () {});
    });

    describe('Executing Arbitration', function () {
        describe('Happy Paths', function () {});
        describe('Exceptions', function () {});
        describe('Events', function () {});
    });
});
