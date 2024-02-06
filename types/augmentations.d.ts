import {Signers} from "./";
import {IDeployContractsOutput} from "../deploy_scripts/main";

declare global {
  namespace Mocha {
    export interface Context {
      signers: Signers;
      contracts: IDeployContractsOutput
    }
  }
}
