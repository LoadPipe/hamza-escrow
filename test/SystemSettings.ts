import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';

const DAO_ROLE =
    '0x3b5d4cc60d3ec3516ee8ae083bd60934f6eb2a6c54b1229985c41bfb092b2603';

describe('SystemSettings', function () {
    let securityContext: any;
    let systemSettings: any;
    let admin: HardhatEthersSigner;
    let nonOwner: HardhatEthersSigner;
    let dao: HardhatEthersSigner;
    let vaultAddress: HardhatEthersSigner;

    this.beforeEach(async () => {
        const [a1, a2, a3, a4, a5, a6, a7] = await hre.ethers.getSigners();
        admin = a1;
        nonOwner = a2;
        vaultAddress = a3;
        dao = a4;

        //deploy security context
        const SecurityContextFactory =
            await hre.ethers.getContractFactory('SecurityContext');
        securityContext = await SecurityContextFactory.deploy(admin.address);

        await securityContext.connect(admin).grantRole(DAO_ROLE, dao.address);

        //deploy settings
        const SystemSettingsFactory =
            await hre.ethers.getContractFactory('SystemSettings');
        systemSettings = await SystemSettingsFactory.deploy(
            securityContext.target,
            vaultAddress,
            100
        );
    });

    describe('Deployment', function () {
        it('Should set the correct property values', async function () {
            expect(await systemSettings.feeBps()).to.equal(100);
            expect(await systemSettings.vaultAddress()).to.equal(vaultAddress);
        });
    });

    describe('Security', function () {
        it('DAO role can set property settings', async function () {
            const vaultAddress2 = admin.address;

            await systemSettings.connect(dao).setFeeBps(204);
            await systemSettings.connect(dao).setVaultAddress(vaultAddress2);

            expect(await systemSettings.feeBps()).to.equal(204);
            expect(await systemSettings.vaultAddress()).to.equal(vaultAddress2);
        });

        it('non-DAO role cannot set property settings', async function () {
            const vaultAddress2 = admin.address;

            await expect(systemSettings.connect(admin).setFeeBps(101)).to.be
                .reverted;
            await expect(
                systemSettings.connect(admin).setVaultAddress(vaultAddress2)
            ).to.be.reverted;

            await expect(systemSettings.connect(nonOwner).setFeeBps(101)).to.be
                .reverted;
            await expect(
                systemSettings.connect(nonOwner).setVaultAddress(vaultAddress2)
            ).to.be.reverted;
        });

        it('can set zero for fee BPS', async function () {
            await expect(systemSettings.connect(dao).setFeeBps(0)).to.not.be
                .reverted;
        });

        it.skip('cannot set zero address for vault', async function () {
            await expect(
                systemSettings.connect(dao).setVaultAddress(ethers.ZeroAddress)
            ).to.be.reverted;
        });
    });
});
