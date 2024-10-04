![GitHub last commit](https://img.shields.io/github/last-commit/la-bomba-studio/hesty-contract)
[![GitHub license](https://img.shields.io/github/license/portuDAO/manual-de-marca)](https://github.com/la-bomba-studio/hesty-contract/blob/main/LICENSE)

![Hesty Logo](https://dev.hesty.labomba.studio/logo.svg)

# Hesty

Hesty is a transparent and secure marketplace for real estate projects that aims to democratize real estate investment. Now everyone can invest in real estate and earn from it!
Hesty will use BASE Blockchain to receive investments and issue property tokens that are representations
of shares of a fund that owns the property.
All the operations in the smart contracts will be done with EURC (EURO CIRCLE) that is MiCA regulated.

In order to keep the platform operating Hesty charges two types of fees that are described below.

Fees Charged By Hesty:
    - Investment Fee: a % that users pay when they invest.
                        For example, if a user invests 2000€ in a property a 3% fee is charged
                                    meaning that the user nees to pay 2000 + (2000 * 0.03) = 2060€
    - Owners Fee: a % of the overall funds raised
                    For example, if a property owner raises 1.000.000€ a 10% fee is charged 
                                meaning that the property owner will receive 900.000€ and Hesty 
                                   will receive 100.000€ 

In addition, a referral fee may be charged but this only happens
when a user was referenced by another user. In this case the fee is calculated
and send to the ReferralSystem Contract.

Fees are not immediately charged because in the case the threshhold is not reached for the raise
all funds must be able to be claimed back by investors including all the fees charged.


NOTE: All this fees can change in the future.


## Hesty Smart Contracts v0.1



## Hesty Token Factory

TokenFactory is a smart contract that manages the issuance of tokens that are representatives of
properties on sale in the Hesty platform.



## Hesty Router

Dedicated Smart Contract that is responsible to manage funds and operations done off chain.
Due to regulatory reasons we can never have the control of move funds directly, so we need
to use a custodian that receives FIAT currency EUR and converts it to EURC.
Also, due to regulatory reasons and in accordance with our communications with the custodian
we partner with they must always send the funds that they have in custody to the same
wallet because that is the only way that automatically can ensure that the receiver of the funds
is safe under AML and KYC regulations.
Hesty router will be the contract that will receive every transfer made from our custodian to our 
smart contracts. After the custodian sends funds it is the responsability of Hesty to reflect off chain 
operations on chain by calling this contract functions. Unfortanely, custodian can make this calls when they send funds.
For example, there is an investment of 2.000€ in a property made with EUR (FIAT). Hesty admins should call the function
offChainBuyTokens in order to allocate the property tokens to the respective user wallet that invested with FIAT.
This synchronization between onchain and offchain for security reasons is not automatic therefore
it may happen that an offchain investment is performed at the same time as an onchain investment and
a property may be oversubscribed. In this case, a FIFO rule applies and if the onchain transaction was 
the last one to occur then it is reverted by admins with ´revertUserBuyTokens´ function.

## Getting Started

To use PropertyFactory, you will need an Web3 wallet and some tokens to pay for transaction fees. You can interact with the contract using a tool like [Metamask](https://metamask.io/).

### Prerequisites

- Node.js v12.18.3 or later
- Hardhat v2.6.2 or later
- Ethers.js v5.4.5 or later
- Chai v4.3.4 or later
### Installation

1. Clone the repository: `git clone ${REPO_URL}`
2. Install dependencies: `npm install`
3. Compile the contracts: `npx hardhat compile`

## Usage

1. Deploy the contract: `npx hardhat run scripts/deploy.js --network polygon-mumbai`
2. Create a new property: `const tokenId = await propertyFactory.createProperty(totalSupply, tokenUri, pricePerToken)`
3. Transfer a property: `await propertyFactory.safeTransferFrom(fromAddress, toAddress, tokenId, amount, data)`
4. Check property details: `const property = await propertyFactory.properties(tokenId)`

## Testing

1. Run the tests: `npx hardhat test`

