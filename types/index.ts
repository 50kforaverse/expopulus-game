import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

export interface Signers {
	creator: SignerWithAddress;
	testAccount2: SignerWithAddress;
	testAccount3: SignerWithAddress;
}
