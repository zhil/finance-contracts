const web3 = require('web3');

module.exports.calculateRequiredPayment = function (
  effectivePriceEth,
  additionalCollateralEth
) {
  const hundredPercentBN = web3.utils.toBN(10000);
  const protocolFeePercentBN = web3.utils.toBN(500);

  const effectivePriceBN = web3.utils.toBN(web3.utils.toWei(effectivePriceEth));
  const principalAmount = !additionalCollateralEth
    ? effectivePriceBN
    : effectivePriceBN.add(
        web3.utils.toBN(web3.utils.toWei(additionalCollateralEth))
      );
  const protocolFeeAmountForCollectBN = effectivePriceBN.mul(protocolFeePercentBN).div(hundredPercentBN);

  return principalAmount.add(protocolFeeAmountForCollectBN);
};
