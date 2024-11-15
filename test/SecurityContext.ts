import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
import { expect } from 'chai';
import hre from 'hardhat';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';

describe('SecurityContext', function () {
    let securityContext: any;
    let owner: HardhatEthersSigner;
    let nonOwner: HardhatEthersSigner;

    this.beforeEach(async () => {
        const [addr1, addr2] = await hre.ethers.getSigners();
        owner = addr1;
        nonOwner = addr2;

        const SecurityContextFactory =
            await hre.ethers.getContractFactory('SecurityContext');
        securityContext = await SecurityContextFactory.deploy(owner.address);
    });

    describe('Deployment', function () {
        it('Should set the right owner', async function () {
            expect(
                await securityContext.hasRole(
                    '0x0000000000000000000000000000000000000000000000000000000000000000',
                    owner.address
                )
            ).to.be.true;
            expect(
                await securityContext.hasRole(
                    '0x0000000000000000000000000000000000000000000000000000000000000000',
                    nonOwner.address
                )
            ).to.be.false;
        });
    });
});
