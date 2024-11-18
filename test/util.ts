export interface IPayment {
    id: any;
    payer: any;
    receiver: any;
    amount: any;
    amountRefunded: any;
    payerReleased: any;
    receiverReleased: any;
    released: any;
    currency: any;
}

export function convertPayment(rawData: any[]): IPayment {
    return {
        id: rawData[0],
        payer: rawData[1],
        receiver: rawData[2],
        amount: rawData[3],
        amountRefunded: rawData[4],
        payerReleased: rawData[5],
        receiverReleased: rawData[6],
        released: rawData[7],
        currency: rawData[8],
    };
}
