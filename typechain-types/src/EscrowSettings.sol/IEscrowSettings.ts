/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BytesLike,
  FunctionFragment,
  Result,
  Interface,
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
} from "../../common";

export interface IEscrowSettingsInterface extends Interface {
  getFunction(nameOrSignature: "feeBps" | "vaultAddress"): FunctionFragment;

  encodeFunctionData(functionFragment: "feeBps", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "vaultAddress",
    values?: undefined
  ): string;

  decodeFunctionResult(functionFragment: "feeBps", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "vaultAddress",
    data: BytesLike
  ): Result;
}

export interface IEscrowSettings extends BaseContract {
  connect(runner?: ContractRunner | null): IEscrowSettings;
  waitForDeployment(): Promise<this>;

  interface: IEscrowSettingsInterface;

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

  feeBps: TypedContractMethod<[], [bigint], "view">;

  vaultAddress: TypedContractMethod<[], [string], "view">;

  getFunction<T extends ContractMethod = ContractMethod>(
    key: string | FunctionFragment
  ): T;

  getFunction(
    nameOrSignature: "feeBps"
  ): TypedContractMethod<[], [bigint], "view">;
  getFunction(
    nameOrSignature: "vaultAddress"
  ): TypedContractMethod<[], [string], "view">;

  filters: {};
}
