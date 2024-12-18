/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumberish,
  BytesLike,
  FunctionFragment,
  Result,
  Interface,
  AddressLike,
  ContractRunner,
  ContractMethod,
  Listener,
} from "ethers";
import type {
  TypedContractEvent,
  TypedDeferredTopicFilter,
  TypedEventLog,
  TypedListener,
  TypedContractMethod,
} from "../common";

export type PaymentInputStruct = {
  currency: AddressLike;
  id: BytesLike;
  receiver: AddressLike;
  payer: AddressLike;
  amount: BigNumberish;
};

export type PaymentInputStructOutput = [
  currency: string,
  id: string,
  receiver: string,
  payer: string,
  amount: bigint
] & {
  currency: string;
  id: string;
  receiver: string;
  payer: string;
  amount: bigint;
};

export interface IEscrowContractInterface extends Interface {
  getFunction(nameOrSignature: "placePayment"): FunctionFragment;

  encodeFunctionData(
    functionFragment: "placePayment",
    values: [PaymentInputStruct]
  ): string;

  decodeFunctionResult(
    functionFragment: "placePayment",
    data: BytesLike
  ): Result;
}

export interface IEscrowContract extends BaseContract {
  connect(runner?: ContractRunner | null): IEscrowContract;
  waitForDeployment(): Promise<this>;

  interface: IEscrowContractInterface;

  queryFilter<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TypedEventLog<TCEvent>>>;
  queryFilter<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TypedEventLog<TCEvent>>>;

  on<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    listener: TypedListener<TCEvent>
  ): Promise<this>;
  on<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    listener: TypedListener<TCEvent>
  ): Promise<this>;

  once<TCEvent extends TypedContractEvent>(
    event: TCEvent,
    listener: TypedListener<TCEvent>
  ): Promise<this>;
  once<TCEvent extends TypedContractEvent>(
    filter: TypedDeferredTopicFilter<TCEvent>,
    listener: TypedListener<TCEvent>
  ): Promise<this>;

  listeners<TCEvent extends TypedContractEvent>(
    event: TCEvent
  ): Promise<Array<TypedListener<TCEvent>>>;
  listeners(eventName?: string): Promise<Array<Listener>>;
  removeAllListeners<TCEvent extends TypedContractEvent>(
    event?: TCEvent
  ): Promise<this>;

  placePayment: TypedContractMethod<
    [payment: PaymentInputStruct],
    [void],
    "payable"
  >;

  getFunction<T extends ContractMethod = ContractMethod>(
    key: string | FunctionFragment
  ): T;

  getFunction(
    nameOrSignature: "placePayment"
  ): TypedContractMethod<[payment: PaymentInputStruct], [void], "payable">;

  filters: {};
}