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

    //TODO: should be a util
    const PROPOSE_RELEASE = 0;
    const PROPOSE_REFUND = 1;

    //TODO: should be a util
    const PROPOSAL_STATUS_ACTIVE = 0;
    const PROPOSAL_STATUS_REJECTED = 1;
    const PROPOSAL_STATUS_ACCEPTED = 2;
    const PROPOSAL_STATUS_EXECUTED = 3;
    const PROPOSAL_STATUS_CANCELLED = 4;

    //TODO: should be a util
    const ESCROW_STATUS_PENDING = 0;
    const ESCROW_STATUS_ACTIVE = 1;
    const ESCROW_STATUS_COMPLETED = 2;
    const ESCROW_STATUS_ARBITRATION = 3;

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
        amount: number,
        autoExecute: boolean = false
    ): Promise<IArbitrationProposal> {
        const tx = await arbitrationModule
            .connect(proposerAccount)
            .proposeArbitration(
                polyEscrow,
                escrowId,
                proposalType,
                amount,
                autoExecute
            );

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

        return await getProposal(proposalId);
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

            it.skip('cannot deploy with an invalid arbitration module', async function () {
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

            it.skip('cannot deploy with a nonexistent arbitration module', async function () {
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
            it.skip('cannot create escrow with an invalid arbitration module', async function () {
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
                    [arbiter1.address, arbiter2.address],
                    1
                );

                //pay into escrow
                await placePayment(escrowId, payer1, amount, isToken);

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
                    [arbiter1.address, arbiter2.address],
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
                            1,
                            false
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
                            1,
                            false
                        )
                ).to.be.revertedWith('InvalidEscrow');
            });

            it.skip('cannot propose arbitration on escrow that has no arbiters assigned', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000;
                const isToken = true;

                //create escrow with no arbiters
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [],
                    0
                );

                //fully pay the escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //propose arbitration
                await expect(
                    arbitrationModule
                        .connect(receiver1)
                        .proposeArbitration(
                            polyEscrow,
                            escrowId,
                            PROPOSE_REFUND,
                            1,
                            false
                        )
                ).to.be.revertedWith('InvalidProposalNoArbiters');
            });

            it('cannot exceed max number of open proposals', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000;
                const isToken = true;

                //create escrow
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [arbiter1.address, arbiter2.address],
                    1
                );

                //propose arbitration 1
                await arbitrationModule
                    .connect(payer1)
                    .proposeArbitration(
                        polyEscrow,
                        escrowId,
                        PROPOSE_REFUND,
                        1,
                        false
                    );

                //propose arbitration 2
                await arbitrationModule
                    .connect(payer1)
                    .proposeArbitration(
                        polyEscrow,
                        escrowId,
                        PROPOSE_REFUND,
                        1,
                        false
                    );

                //propose arbitration 3
                await arbitrationModule
                    .connect(payer1)
                    .proposeArbitration(
                        polyEscrow,
                        escrowId,
                        PROPOSE_REFUND,
                        1,
                        false
                    );

                //propose arbitration 4
                await expect(
                    arbitrationModule
                        .connect(payer1)
                        .proposeArbitration(
                            polyEscrow,
                            escrowId,
                            PROPOSE_REFUND,
                            1,
                            false
                        )
                ).to.be.revertedWith('MaxArbitrationCasesReached');
            });

            it.skip('cannot propose arbitration on an escrow that is in the wrong state', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000;
                const isToken = true;

                //create escrow with no arbiters
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [],
                    0
                );

                //set status to Completed
                await polyEscrow.connect(payer1).releaseEscrow(escrowId);

                //try to propose arbitration
                await expect(
                    arbitrationModule
                        .connect(receiver1)
                        .proposeArbitration(
                            polyEscrow,
                            escrowId,
                            PROPOSE_REFUND,
                            1,
                            false
                        )
                ).to.be.revertedWith('InvalidEscrowState');
            });

            it.skip('cannot propose arbitration for more than the remaining amount of escrow', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000;
                const isToken = true;

                //create escrow with no arbiters
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [],
                    0
                );

                //fully pay the escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //try to propose arbitration: Refund
                await expect(
                    arbitrationModule
                        .connect(receiver1)
                        .proposeArbitration(
                            polyEscrow,
                            escrowId,
                            PROPOSE_REFUND,
                            amount + 1,
                            false
                        )
                ).to.be.revertedWith('InvalidProposalAmount');

                //try to propose arbitration: Release
                await expect(
                    arbitrationModule
                        .connect(receiver1)
                        .proposeArbitration(
                            polyEscrow,
                            escrowId,
                            PROPOSE_RELEASE,
                            amount + 1,
                            false
                        )
                ).to.be.revertedWith('InvalidProposalAmount');
            });
        });

        describe('Events', function () {
            it.skip('arbitration proposal emits ArbitrationProposed', async function () {
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
                    [arbiter1.address, arbiter2.address],
                    1
                );

                //pay into escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //propose arbitration as payer
                const proposalType = PROPOSE_REFUND;
                const proposalAmount = 1000;
                await expect(
                    arbitrationModule
                        .connect(payer1)
                        .proposeArbitration(
                            polyEscrow,
                            escrowId,
                            proposalType,
                            amount,
                            false
                        )
                )
                    .to.emit(arbitrationModule, 'ArbitrationProposed')
                    .withArgs('', escrowId, payer1.address);
            });
        });
    });

    describe('Voting on Arbitration', function () {
        describe('Happy Paths', function () {
            async function canVote(
                account: HardhatEthersSigner,
                vote: boolean
            ) {
                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                const amount = 1000000;
                const isToken = true;

                //arbiters 2/3
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [arbiter1.address, arbiter2.address, arbiter3.address],
                    2
                );

                //pay into escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //propose arbitration as payer
                const proposalType = PROPOSE_REFUND;
                const proposalAmount = amount;
                let proposal = await createProposal(
                    payer1,
                    escrowId,
                    proposalType,
                    proposalAmount
                );

                proposal = await voteProposal(account, proposal.id, vote);

                if (vote) {
                    expect(proposal.votesFor).to.equal(2);
                    expect(proposal.votesAgainst).to.equal(0);
                } else {
                    expect(proposal.votesFor).to.equal(1);
                    expect(proposal.votesAgainst).to.equal(1);
                }
            }

            it('arbiters can vote yes on arbitration', async function () {
                await canVote(arbiter1, true);
            });

            it('arbiters can vote no on arbitration', async function () {
                await canVote(arbiter1, false);
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

                //at this point, votes should be 1:0 for:against (the proposal itself counts as a vote)
                expect((await getProposal(proposal.id)).status).to.equal(
                    PROPOSAL_STATUS_ACTIVE
                );

                //vote on proposal
                await voteProposal(arbiter1, proposal.id, true);
                //at this point, votes should be 2:0 for:against
                expect((await getProposal(proposal.id)).status).to.equal(
                    PROPOSAL_STATUS_ACTIVE
                );

                //vote on proposal
                await voteProposal(arbiter2, proposal.id, true);
                //at this point, votes should be 3:0 for:against, enough to win
                expect((await getProposal(proposal.id)).status).to.equal(
                    PROPOSAL_STATUS_ACCEPTED
                );
            });

            it.skip('votes are counted correctly', async function () {});

            it('proposal is rejected when votes under threshold', async function () {
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

                //at this point, votes should be 1:0 for:against (the proposal itself counts as a vote)
                expect((await getProposal(proposal.id)).status).to.equal(
                    PROPOSAL_STATUS_ACTIVE
                );

                //vote on proposal
                await voteProposal(arbiter1, proposal.id, false);
                //at this point, votes should be 1:1 for:against
                expect((await getProposal(proposal.id)).status).to.equal(
                    PROPOSAL_STATUS_ACTIVE
                );

                //vote on proposal
                await voteProposal(arbiter2, proposal.id, false);
                //at this point, votes should be 1:2 for:against
                expect((await getProposal(proposal.id)).status).to.equal(
                    PROPOSAL_STATUS_REJECTED
                );
            });

            it.skip('single-arbiter proposal is proposed, accepted automatically on proposal creation', async function () {});

            it.skip('zero-arbiter proposal is proposed, accepted automatically on proposal creation', async function () {});
        });

        describe('Exceptions', function () {
            async function cannotVoteUnauthorized(
                account: HardhatEthersSigner
            ) {
                //create the escrow
                const escrowId = ethers.keccak256('0x01');
                const amount = 1000000;
                const isToken = true;

                //arbiters 2/3
                await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [arbiter1.address, arbiter2.address, arbiter3.address],
                    2
                );

                //pay into escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //propose arbitration as payer
                const proposalType = PROPOSE_REFUND;
                const proposalAmount = amount;
                let proposal = await createProposal(
                    payer1,
                    escrowId,
                    proposalType,
                    proposalAmount
                );

                await expect(
                    arbitrationModule
                        .connect(account)
                        .voteArbitration(polyEscrow, proposal.id, true)
                ).to.be.revertedWith('Unauthorized');
            }

            it('payer cannot vote on arbitration', async function () {
                await cannotVoteUnauthorized(payer1);
            });

            it('receiver cannot vote on arbitration', async function () {
                await cannotVoteUnauthorized(receiver1);
            });

            it('stranger cannot vote on arbitration', async function () {
                await cannotVoteUnauthorized(receiver2);
            });

            it.skip('cannot vote on an escrow that is in the wrong state', async function () {});

            it.skip('cannot vote on arbitration that is in the wrong state', async function () {});

            it.skip('cannot vote on proposal more than once', async function () {});

            it('cannot vote on invalid proposal id', async function () {
                const escrowId = ethers.keccak256('0x01');
                const amount = 10000;
                const isToken = true;

                //create escrow with no arbiters
                const escrow = await createEscrow(
                    escrowId,
                    payer1,
                    receiver1.address,
                    amount,
                    isToken,
                    [arbiter1.address],
                    1
                );

                //fully pay the escrow
                await placePayment(escrowId, payer1, amount, isToken);

                //vote on invalid arbitration proposal
                await expect(
                    arbitrationModule
                        .connect(arbiter1)
                        .voteArbitration(
                            polyEscrow,
                            ethers.keccak256('0x01'),
                            true
                        )
                ).to.be.revertedWith('InvalidProposal');
            });

            it.skip('cannot vote on inactive proposal', async function () {});
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
