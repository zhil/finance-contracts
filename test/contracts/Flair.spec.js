const { expect } = require('chai');
const { v4: uuid } = require('uuid');
const web3 = require('web3');

const { setupTest } = require('../setup');
const {
  ZERO_ADDRESS,
  generateFundingOptions,
  hashOffer,
  signOffer,
} = require('../util');

describe('Flair', () => {
  it('should successfully hash an offer', async () => {
    const { userA } = await setupTest();

    const example = {
      beneficiary: userA.signer.address.toLowerCase(),
      fundingOptions: generateFundingOptions({}),
      registry: userA.registryContract.address.toLowerCase(),
      maker: userA.signer.address.toLowerCase(),
      staticTarget: ZERO_ADDRESS,
      staticSelector: '0x00000000',
      staticExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '0',
      salt: '0',
    };

    const hash = await userA.flairContract.hashOffer(...Object.values(example));

    expect(hashOffer(example, userA.flairContract)).to.equal(hash);
  });

  it('does not validate offer parameters with invalid staticTarget', async () => {
    const { userA } = await setupTest();

    const example = {
      beneficiary: userA.signer.address.toLowerCase(),
      fundingOptions: generateFundingOptions({}),
      registry: userA.registryContract.address.toLowerCase(),
      maker: userA.signer.address.toLowerCase(),
      staticTarget: ZERO_ADDRESS,
      staticSelector: '0x00000000',
      staticExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '0',
      salt: '0',
    };

    expect(
      await userA.flairContract.validateOfferParameters(
        ...Object.values(example)
      )
    ).to.equal(false);
  });

  it('validates valid authorization by signature (sign_typed_data)', async () => {
    const { userA } = await setupTest();

    const example = {
      beneficiary: userA.signer.address.toLowerCase(),
      fundingOptions: generateFundingOptions({}),
      registry: userA.registryContract.address.toLowerCase(),
      maker: userA.signer.address.toLowerCase(),
      staticTarget: userA.flairContract.address.toLowerCase(),
      staticSelector: '0x00000000',
      staticExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '1000000000000',
      salt: '100230',
    };

    const signature = await signOffer(
      example,
      userA.signer,
      userA.flairContract
    );
    const hash = hashOffer(example, userA.flairContract);

    expect(
      await userA.flairContract.validateOfferAuthorization(
        hash,
        userA.signer.address.toLowerCase(),
        signature
      )
    ).to.equal(true);
  });
});
