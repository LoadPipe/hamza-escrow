/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Interface, type ContractRunner } from "ethers";
import type {
  ISystemSettings,
  ISystemSettingsInterface,
} from "../../src/ISystemSettings";

const _abi = [
  {
    inputs: [],
    name: "feeBps",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "vaultAddress",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
] as const;

export class ISystemSettings__factory {
  static readonly abi = _abi;
  static createInterface(): ISystemSettingsInterface {
    return new Interface(_abi) as ISystemSettingsInterface;
  }
  static connect(
    address: string,
    runner?: ContractRunner | null
  ): ISystemSettings {
    return new Contract(address, _abi, runner) as unknown as ISystemSettings;
  }
}