const { ethers } = require('hardhat');
const web3 = require('web3');
const sigUtils = require('eth-sig-util');

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ZERO_BYTES32 =
  '0x0000000000000000000000000000000000000000000000000000000000000000';
const EIP712_DOMAIN = {
  name: 'EIP712Domain',
  fields: [
    { name: 'name', type: 'string' },
    { name: 'version', type: 'string' },
    { name: 'chainId', type: 'uint256' },
    { name: 'verifyingContract', type: 'address' },
  ],
};
const EIP712_OFFER = {
  name: 'Offer',
  fields: [
    { name: 'beneficiary', type: 'address' },
    { name: 'fundingOptions', type: 'uint256[8]' },
    { name: 'registry', type: 'address' },
    { name: 'maker', type: 'address' },
    { name: 'staticTarget', type: 'address' },
    { name: 'staticSelector', type: 'bytes4' },
    { name: 'staticExtradata', type: 'bytes' },
    { name: 'maximumFill', type: 'uint256' },
    { name: 'listingTime', type: 'uint256' },
    { name: 'expirationTime', type: 'uint256' },
    { name: 'salt', type: 'uint256' },
  ],
};

const increaseTime = (seconds) => {
  return new Promise((resolve) =>
    web3.currentProvider.send(
      {
        jsonrpc: '2.0',
        method: 'evm_increaseTime',
        params: [seconds],
        id: 0,
      },
      resolve
    )
  );
};

const getEIP712Data = (offer, flairContract) => {
  return {
    types: {
      EIP712Domain: EIP712_DOMAIN.fields,
      Offer: EIP712_OFFER.fields,
    },
    domain: {
      name: 'Flair.Finance',
      version: '0.1',
      chainId: 31337,
      verifyingContract: flairContract.address.toLowerCase(),
    },
    primaryType: 'Offer',
    message: offer,
  };
};

const hashOffer = (offer, flairContract) => {
  const data = getEIP712Data(offer, flairContract);
  return `0x${sigUtils.TypedDataUtils.hashStruct(
    data.primaryType,
    offer,
    data.types
  ).toString('hex')}`;
};

const hashToSign = (offer, flairContract) => {
  return `0x${sigUtils.TypedDataUtils.sign(
    getEIP712Data(offer, flairContract)
  ).toString('hex')}`;
};

const signOffer = async (offer, account, flairContract) => {
  const data = getEIP712Data(offer, flairContract);

  const signature = await account.provider.send('eth_signTypedData_v4', [
    account.address.toLowerCase(),
    data,
  ]);

  const sig = ethers.utils.splitSignature(signature);

  const web3Instance = new web3(account.provider);

  return web3Instance.eth.abi.encodeParameters(
    ['uint8', 'bytes32', 'bytes32'],
    [sig.v, sig.r, sig.s]
  );
};

const generateFundingOptions = ({
  upfrontPayment = web3.utils.toBN(0).toString(),
  cliffPeriod = web3.utils.toBN(0).toString(),
  cliffPayment = web3.utils.toBN(0).toString(),
  vestingPeriod = web3.utils.toBN(24 * 60 * 60).toString(),
  vestingRatio = web3.utils.toBN(700000).toString(),
  priceBancorSupply = web3.utils.toBN(web3.utils.toWei('100')).toString(), // ETH
  priceBancorReserveBalance = web3.utils
    .toBN(web3.utils.toWei('1000'))
    .toString(), // ETH
  priceBancorReserveRatio = web3.utils.toBN(700000).toString(),
}) => {
  return [
    upfrontPayment,
    cliffPeriod,
    cliffPayment,
    vestingPeriod,
    vestingRatio,
    priceBancorSupply,
    priceBancorReserveBalance,
    priceBancorReserveRatio,
  ];
};

module.exports = {
  ZERO_ADDRESS,
  ZERO_BYTES32,
  increaseTime,
  hashOffer,
  hashToSign,
  signOffer,
  generateFundingOptions,
};
