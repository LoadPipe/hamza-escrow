import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';
import { BigNumberish } from 'ethers';

export interface IEscrow {
    id: any;
    payer: string;
    receiver: string;
    arbiters: string[]; // The addresses of the arbiters
    arbiterAssent: boolean[]; // The assent to release of the arbiters
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
}

export function convertEscrow(rawData: any[]): IEscrow {
    return {
        id: rawData[0],
        payer: rawData[1],
        receiver: rawData[2],
        arbiters: rawData[3],
        arbiterAssent: rawData[4],
        arbitersRequired: rawData[5],
        amount: rawData[6],
        currency: rawData[7],
        amountRefunded: rawData[8],
        amountReleased: rawData[9],
        amountPaid: rawData[10],
        timestamp: rawData[11],
        startTime: rawData[12],
        endTime: rawData[13],
        status: rawData[14],
        fullyPaid: rawData[15],
        payerReleased: rawData[16],
        receiverReleased: rawData[17],
        released: rawData[18],
    };
}
