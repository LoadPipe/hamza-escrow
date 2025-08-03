import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';

describe.only('AccountAbstraction', function () {
    let paymasterAccount: HardhatEthersSigner;
    let accountOwnerAccount: HardhatEthersSigner;
    let signer0: HardhatEthersSigner;
    let entryPoint: any;
    let accountFactory: any;

    this.beforeEach(async () => {
        const [a1, a2, a3, a4, a5, a6, a7, a8, a9] =
            await hre.ethers.getSigners();

        paymasterAccount = a1;
        accountOwnerAccount = a2;
        signer0 = a3;

        //deploy entry point
        const EntryPointFactory =
            await hre.ethers.getContractFactory('EntryPoint');
        entryPoint = await EntryPointFactory.deploy();

        //deploy account factory
        const AccountFactoryFactory =
            await hre.ethers.getContractFactory('AccountFactory');
        accountFactory = await AccountFactoryFactory.deploy(entryPoint.target);
    });

    describe('Deployment', function () {
        it('can deploy entry point', async function () {
            await expect(entryPoint.getNonce(accountOwnerAccount.address, 0)).to
                .not.be.reverted;
            expect(
                await entryPoint.getNonce(accountOwnerAccount.address, 0)
            ).to.equal(0);
        });

        it('can deploy account factory', async function () {
            expect(await accountFactory.entryPoint()).to.equal(
                entryPoint.target
            );
        });
    });

    describe('User Operations', function () {
        it.only('can send user operation', async function () {
            const sender = await hre.ethers.getCreateAddress({
                from: accountFactory.target,
                nonce: 1,
            });

            //get contract factories
            const AccountFactoryFactory =
                await hre.ethers.getContractFactory('AccountFactory');
            const AccountFactory =
                await hre.ethers.getContractFactory('Account');

            //generate initCode for createAccount
            const initCode =
                accountFactory.target +
                AccountFactoryFactory.interface
                    .encodeFunctionData('createAccount', [signer0.address])
                    .substring(2);

            //get callData to call the function
            //const callData =
            //    AccountFactory.interface.encodeFunctionData('modifyState');
            const callData = AccountFactory.interface.encodeFunctionData(
                'execute',
                [
                    '0xcafac3dd18ac6c6e92c921884f9e4176737c052c',
                    0,
                    AccountFactory.interface.encodeFunctionData('modifyState'),
                ]
            );

            //deposit funds to the Entrypoint
            await entryPoint.depositTo(sender, {
                value: hre.ethers.parseEther('100'),
            });

            //get EP nonce
            const nonce = await entryPoint.getNonce(sender, 0);
            console.log('NONCE:', nonce);
            console.log('INIT CODE:', initCode);
            console.log('SENDER:', sender);
            console.log('EntryPoint:', entryPoint.target);

            //create the user op
            const userOp: any = {
                sender,
                nonce,
                initCode,
                callData,
                accountGasLimits:
                    '0x00000000000000000000000bebc2000000000000000000000000000000000000',
                preVerificationGas: 200_000_000,
                gasFees:
                    '0x00000000000000000000000bebc2000000000000000000000000000000000000',
                paymasterAndData: '0x',
                signature: '0x',
            };

            console.log(userOp);

            //send the userop
            const tx = await entryPoint.handleOps([userOp], signer0.address);
            const receipt = await tx.wait();

            //TODO: find a better way to get the address
            console.log('ACCOUNT ADDY:', receipt.logs[1].args[1]);

            const account = await hre.ethers.getContractAt(
                'Account',
                receipt.logs[1].args[1]
            );

            //await account.modifyState();
            console.log('counter:', await account.getCounter());
            expect(await account.getCounter()).to.equal(1);

            const userOp2: any = {
                sender,
                nonce: await entryPoint.getNonce(sender, 0),
                initCode: '0x',
                callData,
                accountGasLimits:
                    '0x00000000000000000000000bebc2000000000000000000000000000000000000',
                preVerificationGas: 200_000_000,
                gasFees:
                    '0x00000000000000000000000bebc2000000000000000000000000000000000000',
                paymasterAndData: '0x',
                signature: '0x',
            };

            console.log(userOp2);
            const tx2 = await entryPoint.handleOps([userOp2], signer0.address);
            const receipt2 = await tx2.wait();

            console.log('counter:', await account.getCounter());
            expect(await account.getCounter()).to.equal(2);

            const userOp3: any = {
                sender,
                nonce: await entryPoint.getNonce(sender, 0),
                initCode: '0x',
                callData,
                accountGasLimits:
                    '0x00000000000000000000000bebc2000000000000000000000000000000000000',
                preVerificationGas: 200_000_000,
                gasFees:
                    '0x00000000000000000000000bebc2000000000000000000000000000000000000',
                paymasterAndData: '0x',
                signature: '0x',
            };

            console.log(userOp3);
            const tx3 = await entryPoint.handleOps([userOp3], signer0.address);
            const receipt3 = await tx3.wait();

            console.log('counter:', await account.getCounter());
            expect(await account.getCounter()).to.equal(3);
        });
    });
});
