import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { BigNumberish, keccak256 } from 'ethers';
import {
    IArbitrationProposal,
    IEscrow,
    convertEscrow as convertEscrow,
    convertProposal,
} from './util';

describe('Arbitration', function () {
    let securityContext: any;
    let systemSettings: any;
    let polyEscrow: any;
    let testToken: any;
    let arbitrationModule: any;
    let arbitrationModule2: any;
    let admin: HardhatEthersSigner;
    let nonOwner: HardhatEthersSigner;
    let payer1: HardhatEthersSigner;
    let payer2: HardhatEthersSigner;
    let receiver1: HardhatEthersSigner;
    let receiver2: HardhatEthersSigner;
    let vaultAddress: HardhatEthersSigner;
    let arbiter1: HardhatEthersSigner;
    let arbiter2: HardhatEthersSigner;
    let arbiter3: HardhatEthersSigner;
    let arbiter4: HardhatEthersSigner;
    let arbiter5: HardhatEthersSigner;

    const PROPOSE_RELEASE = 0;
    const PROPOSE_REFUND = 1;

    const PROPOSAL_STATUS_ACTIVE = 0;
    const PROPOSAL_STATUS_REJECTED = 1;
    const PROPOSAL_STATUS_ACCEPTED = 2;
    const PROPOSAL_STATUS_EXECUTED = 3;
    const PROPOSAL_STATUS_CANCELLED = 4;

    //TODO: should be a util function
    async function createEscrow(
        escrowId: string,
        payerAccount: HardhatEthersSigner,
        receiverAddress: string,
        amount: BigNumberish,
        isToken: boolean = false,
        arbiters: string[] = [],
        arbitersRequired: number = arbiters?.length ?? 0,
        startTime: number = 0,
        endTime: number = 0,
        arbitrationModuleAddress: string = ethers.ZeroAddress
    ): Promise<IEscrow> {
        if (isToken)
            await testToken
                .connect(payerAccount)
                .approve(polyEscrow.target, amount);

        await polyEscrow.connect(payerAccount).createEscrow({
            currency: isToken ? testToken.target : ethers.ZeroAddress,
            id: escrowId,
            receiver: receiverAddress,
            payer: payerAccount.address,
            arbiters,
            arbitersRequired,
            amount,
            startTime,
            endTime,
            arbitrationModule: arbitrationModuleAddress,
        });

        //return escrow
        const escrow = convertEscrow(await polyEscrow.getEscrow(escrowId));
        return escrow;
    }

    //TODO: should be a util function
    async function placePayment(
        escrowId: string,
        payerAccount: HardhatEthersSigner,
        amount: BigNumberish,
        isToken: boolean = false
    ): Promise<IEscrow> {
        if (isToken) {
            await testToken
                .connect(payerAccount)
                .approve(polyEscrow.target, amount);

            await polyEscrow.connect(payerAccount).placePayment({
                escrowId: escrowId,
                currency: testToken.target,
                amount,
            });
        } else {
            await polyEscrow.connect(payerAccount).placePayment(
                {
                    escrowId: escrowId,
                    currency: ethers.ZeroAddress,
                    amount,
                },
                { value: amount }
            );
        }

        //return escrow
        const escrow = convertEscrow(await polyEscrow.getEscrow(escrowId));
        return escrow;
    }

    async function createProposal(
        proposerAccount: HardhatEthersSigner,
        escrowId: string,
        proposalType: number,
        amount: number
    ): Promise<IArbitrationProposal> {
        const tx = await arbitrationModule
            .connect(proposerAccount)
            .proposeArbitration(polyEscrow, escrowId, proposalType, amount);

        //capture the event, and the id from it
        const receipt = await tx.wait();
        const id = receipt.logs[0].topics[1];

        //retrieve the proposal
        return await getProposal(id);
    }

    async function getProposal(proposalId: any): Promise<IArbitrationProposal> {
        const proposal = await arbitrationModule.getProposal(proposalId);

        return convertProposal(proposal);
    }

    async function voteProposal(
        account: HardhatEthersSigner,
        proposalId: any,
        vote: boolean
    ) {
        await arbitrationModule
            .connect(account)
            .voteArbitration(polyEscrow, proposalId, vote);
    }

    async function deploySecondArbitrationModule() {
        const ArbitrationModuleFactory =
            await hre.ethers.getContractFactory('ArbitrationModule');
        arbitrationModule2 = await ArbitrationModuleFactory.deploy();
    }

    this.beforeEach(async () => {
        const [a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12] =
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
        arbiter3 = a10;
        arbiter4 = a11;
        arbiter5 = a12;

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
            it('can deploy with valid arbitration module', async function () {
                expect(await polyEscrow.defaultArbitrationModule()).to.equal(
                    arbitrationModule.target
                );
            });
        });

        describe('Exceptions', function () {
            it('cannot deploy with a zero-address arbitration module', async function () {
                //polyEscrow factory
                const PolyEscrowFactory =
                    await hre.ethers.getContractFactory('PolyEscrow');

                //deploy with zero address
                await expect(
                    PolyEscrowFactory.deploy(
                        securityContext.target,
                        systemSettings.target,
                        ethers.ZeroAddress //should be an IArbitrationModule
                    )
                ).to.be.revertedWith('InvalidArbitrationModule');
            });

            it('cannot deploy with an invalid arbitration module', async function () {
                //polyEscrow factory
                const PolyEscrowFactory =
                    await hre.ethers.getContractFactory('PolyEscrow');

                //deploy with invalid arb module (thing that is not an IArbitrationModule)
                await expect(
                    PolyEscrowFactory.deploy(
                        securityContext.target,
                        systemSettings.target,
                        testToken.target //should be an IArbitrationModule
                    )
                ).to.be.revertedWith('InvalidArbitrationModule');
            });

            it('cannot deploy with a nonexistent arbitration module', async function () {
                //polyEscrow factory
                const PolyEscrowFactory =
                    await hre.ethers.getContractFactory('PolyEscrow');

                //deploy with invalid arb module (non-existent contract address)
                await expect(
                    PolyEscrowFactory.deploy(
                        securityContext.target,
                        systemSettings.target,
                        arbiter1.address //should be an IArbitrationModule
                    )
                ).to.be.revertedWith('InvalidArbitrationModule');
            });
        });
    });

    describe('Escrow Creation', function () {
        describe('Happy Paths', function () {
            it('can create escrow with valid custom arbitration module', async function () {
                //deploy a new arbitration module
                await deploySecondArbitrationModule();

                //create escrow
                const escrowId = ethers.keccak256('0x01');
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    100,
                    true,
                    [arbiter1.address, arbiter2.address],
                    1,
                    undefined,
                    undefined,
                    arbitrationModule2.target
                );

                //check arbitration module
                expect(escrow.arbitrationModule).to.equal(
                    arbitrationModule2.target
                );
                expect(escrow.arbitrationModule).to.not.equal(
                    arbitrationModule.target
                );
            });

            it('can create escrow with valid default arbitration module', async function () {
                //create escrow
                const escrowId = ethers.keccak256('0x01');
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    100,
                    true,
                    [arbiter1.address, arbiter2.address],
                    1
                );

                //check arbitration module
                expect(escrow.arbitrationModule).to.equal(
                    arbitrationModule.target
                );
            });
        });

        describe('Exceptions', function () {
            it('cannot create escrow with an invalid arbitration module', async function () {
                //create escrow
                const escrowId = ethers.keccak256('0x01');
                await expect(
                    createEscrow(
                        escrowId,
                        payer1,
                        receiver1.address,
                        100,
                        true,
                        [arbiter1.address, arbiter2.address],
                        1,
                        undefined,
                        undefined,
                        systemSettings.target
                    )
                ).to.be.revertedWith('InvalidArbitrationModule');
            });
        });

        describe('Events', function () {});
    });

    describe('Proposing Arbitration', function () {
        describe('Happy Paths', function () {
            async function canProposeArbitration(account: HardhatEthersSigner) {
                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                const amount = 1000000;
                const isToken = true;
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [(arbiter1.address, arbiter2.address)],
                    1
                );

                //propose arbitration as payer
                const proposalType = PROPOSE_REFUND;
                const proposalAmount = 1000;
                const proposal = await createProposal(
                    account,
                    escrowId,
                    proposalType,
                    proposalAmount
                );

                //verify proposal
                expect(proposal.amount).to.equal(proposalAmount);
                expect(proposal.escrowId).to.equal(escrowId);
                expect(proposal.proposalType).to.equal(proposalType);
            }

            it('payer can propose arbitration', async function () {
                await canProposeArbitration(payer1);
            });

            it('receiver can propose arbitration', async function () {
                await canProposeArbitration(receiver1);
            });
        });

        describe('Exceptions', function () {
            async function cannotProposeArbitrationUnauthorized(
                escrowId: string,
                proposerAccount: HardhatEthersSigner
            ) {
                escrowId = ethers.keccak256(escrowId);
                const amount = 10000;
                const isToken = true;

                //create escrow
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [(arbiter1.address, arbiter2.address)],
                    1
                );

                //propose arbitration
                await expect(
                    arbitrationModule
                        .connect(proposerAccount)
                        .proposeArbitration(
                            polyEscrow,
                            escrowId,
                            PROPOSE_REFUND,
                            1
                        )
                ).to.be.revertedWith('Unauthorized');
            }

            it('stranger cannot propose arbitration', async function () {
                await cannotProposeArbitrationUnauthorized('0x01', receiver2);
            });

            it('arbiter cannot propose arbitration', async function () {
                await cannotProposeArbitrationUnauthorized('0x01', arbiter1);
                await cannotProposeArbitrationUnauthorized('0x02', arbiter2);
            });

            it('cannot propose arbitration on invalid escrow id', async function () {
                const escrowId = ethers.keccak256('0x01');

                //propose arbitration
                await expect(
                    arbitrationModule
                        .connect(receiver1)
                        .proposeArbitration(
                            polyEscrow,
                            escrowId,
                            PROPOSE_REFUND,
                            1
                        )
                ).to.be.revertedWith('InvalidEscrow');
            });

            it.skip('cannot propose arbitration on escrow that has no arbiters assigned', async function () {});

            it.skip('cannot vote on invalid proposal id', async function () {});

            it.skip('cannot vote on inactive proposal', async function () {});

            it.skip('cannot exceed max number of open proposals', async function () {});

            it.skip('cannot propose arbitration on an escrow that is in the wrong state', async function () {});

            it.skip('cannot propose arbitration for more than the remaining amount of escrow', async function () {});
        });

        describe('Events', function () {
            it.skip('arbitration proposal emits ArbitrationProposed', async function () {});
        });
    });

    describe('Voting on Arbitration', function () {
        describe('Happy Paths', function () {
            async function canVote(
                account: HardhatEthersSigner,
                vote: boolean
            ) {}

            it.skip('arbiters can vote yes on arbitration', async function () {
                await canVote(arbiter1, true);
                await canVote(arbiter2, true);
            });

            it.skip('arbiters can vote no on arbitration', async function () {
                await canVote(arbiter1, false);
                await canVote(arbiter2, false);
            });

            it('proposal is accepted when votes over threshold', async function () {
                //create an escrow with 3/5
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000;
                const isToken = true;

                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [
                        arbiter1.address,
                        arbiter2.address,
                        arbiter3.address,
                        arbiter4.address,
                        arbiter5.address,
                    ],
                    3
                );

                //fully pay the escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //propose arbitration for full refund
                const proposal = await createProposal(
                    payer1,
                    escrowId,
                    PROPOSE_REFUND,
                    amount
                );

                expect((await getProposal(proposal.id)).status).to.equal(
                    PROPOSAL_STATUS_ACTIVE
                );

                //vote on proposal
                await voteProposal(proposal.id, arbiter1, true);
                expect((await getProposal(proposal.id)).status).to.equal(
                    PROPOSAL_STATUS_ACTIVE
                );

                //vote on proposal
                await voteProposal(proposal.id, arbiter2, true);
                expect((await getProposal(proposal.id)).status).to.equal(
                    PROPOSAL_STATUS_ACTIVE
                );

                //vote on proposal
                await voteProposal(proposal.id, arbiter3, true);
                expect((await getProposal(proposal.id)).status).to.equal(
                    PROPOSAL_STATUS_ACCEPTED
                );
            });

            it.skip('proposal is rejected when votes under threshold', async function () {});

            it.skip('single-arbiter proposal is voted, accepted automatically on proposal creation', async function () {});
        });

        describe('Exceptions', function () {
            async function cannotVoteUnauthorized(
                account: HardhatEthersSigner
            ) {}

            it.skip('payer cannot vote on arbitration', async function () {
                await cannotVoteUnauthorized(payer1);
            });

            it.skip('receiver cannot vote on arbitration', async function () {
                await cannotVoteUnauthorized(receiver1);
            });

            it.skip('stranger cannot vote on arbitration', async function () {
                await cannotVoteUnauthorized(receiver2);
            });

            it.skip('cannot vote on an escrow that is in the wrong state', async function () {});

            it.skip('cannot vote on arbitration that is in the wrong state', async function () {});

            it.skip('cannot vote on proposal more than once', async function () {});
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
