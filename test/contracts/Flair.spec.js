const { expect } = require('chai');
const { v4: uuid } = require('uuid');
const web3 = require('web3');

const { setupTest } = require('../setup');
const { ZERO_ADDRESS, hashOffer, generateFundingOptions } = require('../util');

describe('Flair', () => {
  it('should successfully hash an offer', async () => {
    const { userA } = await setupTest();

    const example = {
      beneficiary: userA.signer.address,
      fundingOptions: generateFundingOptions({}),
      registry: userA.registryContract.address,
      maker: userA.signer.address,
      staticTarget: ZERO_ADDRESS,
      staticSelector: '0x00000000',
      staticExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '0',
      salt: '0',
    };

    const hash = await userA.flairContract.hashOffer(...Object.values(example));

    expect(hashOffer(example)).to.equal(hash);
  });
});
