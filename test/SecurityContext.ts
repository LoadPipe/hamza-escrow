import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
import { expect } from 'chai';
import hre from 'hardhat';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';

const ADMIN_ROLE='0x0000000000000000000000000000000000000000000000000000000000000000';

describe('SecurityContext', function () {
    let securityContext: any;
    let admin: HardhatEthersSigner;
    let nonAdmin1: HardhatEthersSigner;
    let nonAdmin2: HardhatEthersSigner;

    this.beforeEach(async () => {
        const [a1, a2, a3] = await hre.ethers.getSigners();
        admin = a1;
        nonAdmin1 = a2;
        nonAdmin2 = a3;

        const SecurityContextFactory =
            await hre.ethers.getContractFactory('SecurityContext');
        securityContext = await SecurityContextFactory.deploy(admin.address);
    });

    describe('Deployment', function () {
        it('Should set the right owner', async function () {
            expect(
                await securityContext.hasRole(
                    ADMIN_ROLE,
                    admin.address
                )
            ).to.be.true;
            expect(
                await securityContext.hasRole(
                    ADMIN_ROLE,
                    nonAdmin1.address
                )
            ).to.be.false;
            expect(
                await securityContext.hasRole(
                    ADMIN_ROLE,
                    nonAdmin2.address
                )
            ).to.be.false;
        });
    });


    describe("Transfer Adminship", function () {
        it("can grant admin to self", async function () {
            await securityContext.grantRole(ADMIN_ROLE, admin.address);

            expect(await securityContext.hasRole(ADMIN_ROLE, admin.address)).to.be.true;
            expect(await securityContext.hasRole(ADMIN_ROLE, nonAdmin1.address)).to.be.false;
            expect(await securityContext.hasRole(ADMIN_ROLE, nonAdmin2.address)).to.be.false;
        });

        it("can transfer admin to another", async function () {
            await securityContext.grantRole(ADMIN_ROLE, nonAdmin1.address);

            //now there are two admins
            expect(await securityContext.hasRole(ADMIN_ROLE, admin.address)).to.be.true;
            expect(await securityContext.hasRole(ADMIN_ROLE, nonAdmin1.address)).to.be.true;
            expect(await securityContext.hasRole(ADMIN_ROLE, nonAdmin2.address)).to.be.false;

            await securityContext.connect(nonAdmin1).revokeRole(ADMIN_ROLE, admin.address);

            //now origin admin has had adminship revoked 
            expect(await securityContext.hasRole(ADMIN_ROLE, admin.address)).to.be.false;
            expect(await securityContext.hasRole(ADMIN_ROLE, nonAdmin1.address)).to.be.true;
            expect(await securityContext.hasRole(ADMIN_ROLE, nonAdmin2.address)).to.be.false;
        });

        it("can pass adminship along", async function () {
            await securityContext.grantRole(ADMIN_ROLE, nonAdmin1.address);
            await securityContext.connect(nonAdmin1).revokeRole(ADMIN_ROLE, admin.address);
            await securityContext.connect(nonAdmin1).grantRole(ADMIN_ROLE, nonAdmin2.address);
            await securityContext.connect(nonAdmin2).revokeRole(ADMIN_ROLE, nonAdmin1.address);

            //in the end, adminship has passed from admin to nonAdmin1 to nonAdmin2
            expect(await securityContext.hasRole(ADMIN_ROLE, admin.address)).to.be.false;
            expect(await securityContext.hasRole(ADMIN_ROLE, nonAdmin1.address)).to.be.false;
            expect(await securityContext.hasRole(ADMIN_ROLE, nonAdmin2.address)).to.be.true;
        });
    });
});
