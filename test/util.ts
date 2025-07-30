import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { BigNumberish } from 'ethers';

export interface IEscrow {
    id: any;
    payer: string;
    receiver: string;
    arbiters: string[]; // The addresses of the arbiters
    arbitersRequired: number; // The number of arbiters consent required
    amount: any; // The total amount of the escrow
    currency: string; //The currency addres, 0x0 for native
    amountRefunded: any; // The amount refunded so far
    amountReleased: any; // The amount released so far
    amountPaid: any; // The amount paid so far
    timestamp: number; // The timestamp when the proposal was made
    startTime: number; // The timestamp when the escrow period begins
    endTime: number; //The timestamp when the escrow period ends
    status: number; // 0 = pending, 1 = active, 2 = completed, 3=arbitration
    fullyPaid: boolean; // Indicates if the escrow is fully paid
    payerReleased: boolean;
    receiverReleased: boolean;
    released: boolean;
    arbitrationModule: string;
}

export interface IArbitrationProposal {
    id: any;
    escrowId: any;
    proposalType: number;
    status: number;
    proposer: string;
    amount: any;
    votesFor: number;
    votesAgainst: number;
}

export function convertEscrow(rawData: any[]): IEscrow {
    return {
        id: rawData[0],
        payer: rawData[1],
        receiver: rawData[2],
        arbiters: rawData[3],
        arbitersRequired: rawData[4],
        amount: rawData[5],
        currency: rawData[6],
        amountRefunded: rawData[7],
        amountReleased: rawData[8],
        amountPaid: rawData[9],
        timestamp: rawData[10],
        startTime: rawData[11],
        endTime: rawData[12],
        status: rawData[13],
        fullyPaid: rawData[14],
        payerReleased: rawData[15],
        receiverReleased: rawData[16],
        released: rawData[17],
        arbitrationModule: rawData[18],
    };
}

export function convertProposal(rawData: any[]): IArbitrationProposal {
    return {
        id: rawData[0],
        escrowId: rawData[1],
        proposalType: rawData[2],
        status: rawData[3],
        proposer: rawData[4],
        amount: rawData[5],
        votesFor: rawData[6],
        votesAgainst: rawData[7],
    };
}
