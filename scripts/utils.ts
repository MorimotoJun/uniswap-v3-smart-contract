"use strict";

import * as fs from "fs";
import * as path from "path";

// J : pathを定義
// E : define path
const ROOT_PATH = path.resolve(__dirname, "..");
const ARTIFACTS = path.join(ROOT_PATH, "artifacts", "contracts");
const UTILS = path.join(ROOT_PATH, "utils");


interface ABI {
    abi: any;
    bytecode: string;
}

/**
 * J : 特定のコントラクトのABIを取得する
 * E : get specific ABI from artifacts
 *
 * @param {ContractEnum} CONTRACT the name of the contract
 * @returns { abi: any, bytecode: string }
 */
export function getAbi(CONTRACT: ContractEnum): ABI {
    const p = path.join(ARTIFACTS, `${CONTRACT}.sol`, `${CONTRACT}.json`);
    const str = fs.readFileSync(p).toString();
    const { abi, bytecode } = JSON.parse(str);

    return { abi, bytecode };
}

export enum ContractEnum {
    Swap = 'SimpleSwap',
}

export function getTokenABI(): any {
    const p = path.join(UTILS, 'WrappedToken.json');
    const str = fs.readFileSync(p).toString();
    return JSON.parse(str);
}