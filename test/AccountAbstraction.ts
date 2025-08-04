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
        async function fundGas(from: HardhatEthersSigner, to: string) {
            const transaction = await from.sendTransaction({
                to,
                value: hre.ethers.parseEther('1'),
            });
        }

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

            //fund gas
            await fundGas(
                signer0,
                '0xCafac3dD18aC6c6e92c921884f9E4176737C052c'
            );

            //create the user op
            const userOp: any = {
                sender,
                nonce,
                initCode,
                callData,
                callGasLimit: 200_000_000,
                accountGasLimits:
                    '0x0000000000000000000020000000000000000000000000000000000000200000',
                preVerificationGas: 200_000_000,
                gasFees:
                    '0x0000000000000000000000000002000000000000000000000000000000200000',
                paymasterAndData: '0x',
                //paymasterAccount.address +
                //'0000000000000000000000000000000000000000000000000000000000030d40' + // 200000 verification gas
                //'000000000000000000000000000000000000000000000000000000000000c350', // 50000 postop gas
                signature: '0x',
            };

            console.log(userOp);
            await entryPoint.depositTo(paymasterAccount.address, {
                value: ethers.parseEther('10'),
            });

            //send the userop
            const tx = await entryPoint.handleOps(
                [userOp],
                paymasterAccount.address
            );
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
                callGasLimit: 500_000, // Reasonable for most operations
                accountGasLimits:
                    '0x' +
                    (100_000).toString(16).padStart(64, '0') + // verificationGasLimit
                    (500_000).toString(16).padStart(64, '0'), // callGasLimit (matches above)
                preVerificationGas: 50_000, // Reasonable pre-verification
                gasFees:
                    '0x' +
                    (2_000_000_000).toString(16).padStart(32, '0') + // maxPriorityFeePerGas (2 gwei)
                    (20_000_000_000).toString(16).padStart(32, '0'), // maxFeePerGas (20 gwei)
                paymasterAndData: '0x',
                signature: '0x',
            };

            console.log(userOp2);
            (
                await entryPoint.depositTo(paymasterAccount.address, {
                    value: ethers.parseEther('10'),
                })
            ).wait();
            return;

            const tx2 = await entryPoint.handleOps(
                [userOp2],
                paymasterAccount.address
            );
            const receipt2 = await tx2.wait();

            console.log('counter:', await account.getCounter());
            expect(await account.getCounter()).to.equal(2);

            const userOp3: any = {
                sender,
                nonce: await entryPoint.getNonce(sender, 0),
                initCode: '0x',
                callData,
                callGasLimit: 200_000_000,
                accountGasLimits:
                    '0x0000000000000100bebc20000000000000000000000000000000000000002000',
                preVerificationGas: 200_000_000,
                gasFees:
                    '0x0000000000000100bebc2000000000000000000000000000000000000002000',
                paymasterAndData: '0x',
                signature: '0x',
            };

            console.log(userOp3);
            (
                await entryPoint.depositTo(paymasterAccount.address, {
                    value: ethers.parseEther('10'),
                })
            ).wait();

            const tx3 = await entryPoint.handleOps([userOp3], signer0.address);
            const receipt3 = await tx3.wait();

            console.log('counter:', await account.getCounter());
            expect(await account.getCounter()).to.equal(3);
        });
    });
});
