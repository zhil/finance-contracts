const web3 = require('web3');
const { structHash } = require('./eip712');

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ZERO_BYTES32 =
  '0x0000000000000000000000000000000000000000000000000000000000000000';

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

const eip712Offer = {
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

const hashOffer = (offer) => {
  return `0x${structHash(eip712Offer.name, eip712Offer.fields, offer).toString(
    'hex'
  )}`;
};

const generateFundingOptions = ({
  upfrontPayment = web3.utils.toBN(0).toString(),
  cliffPeriod = web3.utils.toBN(0).toString(),
  cliffPayment = web3.utils.toBN(0).toString(),
  vestingPeriod = web3.utils.toBN(24 * 60 * 60).toString(),
  vestingRatio = web3.utils.toBN(700000).toString(),
  priceBancorSupply = web3.utils.toBN(web3.utils.toWei('100')).toString(), // ETH
  priceBancorReserveBalance = web3.utils.toBN(web3.utils.toWei('1000')).toString(), // ETH
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
  generateFundingOptions
};
