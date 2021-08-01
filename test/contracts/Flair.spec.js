const { expect } = require('chai');
const { v4: uuid } = require('uuid');
const web3 = require('web3');

const { setupTest } = require('../setup');
const { ZERO_ADDRESS } = require('./util');

describe('Flair', () => {
  it('should successfully hash an offer', async () => {
    const { userA } = await setupTest();

    const example = {
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
    let hash = await userA.flairContract.hashOffer(example);
    assert.equal(hashOffer(example), hash, 'Incorrect order hash');

    await expect(await userA.flairContract.name()).to.equal('Flair.Finance');
  });
});
