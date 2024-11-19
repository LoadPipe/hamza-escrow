import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
import { expect } from 'chai';
import hre from 'hardhat';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';

const ADMIN_ROLE='0x0000000000000000000000000000000000000000000000000000000000000000';

const ARBITER_ROLE =
    '0xbb08418a67729a078f87bbc8d02a770929bb68f5bfdf134ae2ead6ed38e2f4ae';

const DAO_ROLE =
    '0x3b5d4cc60d3ec3516ee8ae083bd60934f6eb2a6c54b1229985c41bfb092b2603';


export async function grantRole(secMan: any, role: string, toAddress: string, caller: HardhatEthersSigner) {
    await secMan.connect(caller).grantRole(role, toAddress);
}

export async function revokeRole(secMan: any, role: string, fromAddress: string, caller: HardhatEthersSigner) {
    await secMan.connect(caller).grantRole(role, fromAddress);
}

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

    describe("Restrictions", function () {

        this.beforeEach(async function () {
            await grantRole(securityContext, ARBITER_ROLE, admin.address, admin);
            await grantRole(securityContext, DAO_ROLE, admin.address, admin);
        });

        it.skip("cannot set zero address to security context", async function () {
            await expectRevert(
                () => masterSwitch.setSecurityContext(ethers.ZeroAddress),
                constants.errorMessages.ZERO_ADDRESS
            ); 
        });

        it.skip("cannot set zero address to product nft security manager", async function () {
            await expectRevert(
                () => masterSwitch.setSecurityContext(ethers.ZeroAddress),
                constants.errorMessages.ZERO_ADDRESS
            ); 
        });

        it.skip("cannot set zero address to whitelist security manager", async function () {
            await expectRevert(
                () => masterSwitch.setSecurityContext(ethers.ZeroAddress),
                constants.errorMessages.ZERO_ADDRESS
            ); 
        });

        it.skip("cannot set bogus address for security manager", async function () {
            await expectRevert(
                () => masterSwitch.setSecurityContext(paymentSwitch.target.toString()),
                constants.errorMessages.INVALID_CONTRACT_METHOD
            );
        });

        it.skip("cannot set non-contract address for security manager", async function () {
            await expectRevert(
                () => masterSwitch.setSecurityContext(admin.address),
                constants.errorMessages.INVALID_CONTRACT_METHOD
            );
        });

        it("admin cannot renounce admin role", async function () {

            //admin has admin role
            expect(await securityContext.hasRole(ADMIN_ROLE, admin.address)).to.be.true;

            //try to renounce
            await securityContext.renounceRole(ADMIN_ROLE, admin.address);

            //role not renounced (should fail silently)
            expect(await securityContext.hasRole(ADMIN_ROLE, admin.address)).to.be.true;
        });

        it("admin can renounce non-admin role", async function () {

            //admin has role
            expect(await securityContext.hasRole(ARBITER_ROLE, admin.address)).to.be.true;
            expect(await securityContext.hasRole(DAO_ROLE, admin.address)).to.be.true;

            //try to renounce
            await securityContext.renounceRole(ARBITER_ROLE, admin.address);
            await securityContext.renounceRole(DAO_ROLE, admin.address);

            //role is renounced
            expect(await securityContext.hasRole(ARBITER_ROLE, admin.address)).to.be.false;
            expect(await securityContext.hasRole(DAO_ROLE, admin.address)).to.be.false;
        });

        it("admin can revoke their own non-admin role", async function () {

            //admin has admin role
            expect(await securityContext.hasRole(ARBITER_ROLE, admin.address)).to.be.true;
            expect(await securityContext.hasRole(DAO_ROLE, admin.address)).to.be.true;

            //try to renounce
            await securityContext.revokeRole(ARBITER_ROLE, admin.address);
            await securityContext.revokeRole(DAO_ROLE, admin.address);

            //role is renounced
            expect(await securityContext.hasRole(ARBITER_ROLE, admin.address)).to.be.false;
            expect(await securityContext.hasRole(DAO_ROLE, admin.address)).to.be.false;
        });

        it("admin cannot revoke their own admin role", async function () {

            //admin has admin role
            expect(await securityContext.hasRole(ADMIN_ROLE, admin.address)).to.be.true;

            //try to renounce
            await securityContext.revokeRole(ADMIN_ROLE, admin.address);

            //role not renounced (should fail silently)
            expect(await securityContext.hasRole(ADMIN_ROLE, admin.address)).to.be.true;
        });

        it("admin role can be revoked by another admin", async function () {

            //grant admin to another 
            await securityContext.grantRole(ADMIN_ROLE, nonAdmin1.address);

            //now both users are admin 
            expect(await securityContext.hasRole(ADMIN_ROLE, admin.address)).to.be.true;
            expect(await securityContext.hasRole(ADMIN_ROLE, nonAdmin1.address)).to.be.true;

            //2 admins enter, 1 admin leaves
            await securityContext.connect(nonAdmin1).revokeRole(ADMIN_ROLE, admin.address);

            //only one admin remains
            expect(await securityContext.hasRole(ADMIN_ROLE, admin.address)).to.be.false;
            expect(await securityContext.hasRole(ADMIN_ROLE, nonAdmin1.address)).to.be.true;
        });

        it("admin role can be transferred in two steps", async function () {

            const a = admin;
            const b = nonAdmin1;

            //beginning state: a is admin, b is not 
            expect(await securityContext.hasRole(ADMIN_ROLE, a.address)).to.be.true;
            expect(await securityContext.hasRole(ADMIN_ROLE, b.address)).to.be.false;

            //transfer in two steps 
            await securityContext.grantRole(ADMIN_ROLE, b.address);
            await securityContext.connect(b).revokeRole(ADMIN_ROLE, a.address);

            //beginning state: b is admin, a is not 
            expect(await securityContext.hasRole(ADMIN_ROLE, a.address)).to.be.false;
            expect(await securityContext.hasRole(ADMIN_ROLE, b.address)).to.be.true;

        });

        it("cannot renounce another address's role", async function () {
            await securityContext.grantRole(ARBITER_ROLE, nonAdmin1.address);
            await securityContext.grantRole(ARBITER_ROLE, nonAdmin2.address);

            expect(await securityContext.hasRole(ARBITER_ROLE, nonAdmin1.address)).to.be.true;
            expect(await securityContext.hasRole(ARBITER_ROLE, nonAdmin2.address)).to.be.true;

            /*
            await expectRevert(
                () => securityContext.connect(nonAdmin1).renounceRole(ARBITER_ROLE, nonAdmin2.address),
                constants.errorMessages.ACCESS_CONTROL_RENOUNCE
            );

            await expectRevert(
                () => securityContext.connect(nonAdmin2).renounceRole(ARBITER_ROLE, nonAdmin1.address),
                constants.errorMessages.ACCESS_CONTROL_RENOUNCE
            );
            */

            await expect(securityContext.connect(nonAdmin1).renounceRole(ARBITER_ROLE, nonAdmin1.address)).to.not.be.reverted;
            await expect(securityContext.connect(nonAdmin2).renounceRole(ARBITER_ROLE, nonAdmin2.address)).to.not.be.reverted;
        });
    });
});
