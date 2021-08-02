const { expect } = require('chai');
const { v4: uuid } = require('uuid');
const web3 = require('web3');

const { setupTest } = require('../setup');
const {
  ZERO_ADDRESS,
  generateFundingOptions,
  hashOffer,
  signOffer,
  prepareOfferArgs,
} = require('../util');

describe('Flair', () => {
  const web3Instance = new web3(web3.currentProvider);

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

  it('should calculate funding costs of various fills for 0.01 ETH fixed-price', async () => {
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

    const hash = hashOffer(example, userA.flairContract);

    const resultOne = await userA.flairContract.getOfferFundingCost(
      userA.signer.address,
      hash,
      generateFundingOptions({}),
      1
    );
    const resultTwo = await userA.flairContract.getOfferFundingCost(
      userA.signer.address,
      hash,
      generateFundingOptions({}),
      2
    );
    const resultFive = await userA.flairContract.getOfferFundingCost(
      userA.signer.address,
      hash,
      generateFundingOptions({}),
      5
    );

    expect(web3.utils.fromWei(resultOne.fundingCost.toString())).to.equal(
      '0.01'
    );
    expect(web3.utils.fromWei(resultTwo.fundingCost.toString())).to.equal(
      '0.02'
    );
    expect(web3.utils.fromWei(resultFive.fundingCost.toString())).to.equal(
      '0.05'
    );
  });

  it('should successfully fund an offer for 1 ETH fixed-price', async () => {
    const { userA, userB } = await setupTest();

    const targetSelector = web3Instance.eth.abi.encodeFunctionSignature(
      'mintExact(address,uint256)'
    );
    const targetExtradata = web3Instance.eth.abi.encodeParameters(
      ['address', 'uint256'],
      [userA.signer.address.toLowerCase(), 555]
    );

    const staticSelector = web3Instance.eth.abi.encodeFunctionSignature(
      'acceptContractAndSelectorAddUint32FillFromExtraData(bytes,address[5],uint8,uint256[5],bytes)'
    );
    const staticExtradata = web3Instance.eth.abi.encodeParameters(
      ['address', 'bytes4', 'uint32'],
      [userA.testERC721.address.toLowerCase(), targetSelector, 1]
    );

    const example = {
      beneficiary: userA.signer.address.toLowerCase(),
      fundingOptions: generateFundingOptions({
        priceBancorSupply: web3.utils.toBN(1000).toString(), // Initial Supply (e.g. Fills)
        priceBancorReserveBalance: web3.utils
          .toBN(web3.utils.toWei('1000'))
          .toString(), // Initial Reserve (e.g. ETH)
        priceBancorReserveRatio: web3.utils.toBN(1000000).toString(),
      }),
      registry: userA.registryContract.address.toLowerCase(),
      maker: userA.signer.address.toLowerCase(),
      staticTarget: userA.staticValidators.address.toLowerCase(),
      staticSelector,
      staticExtradata,
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '1000000000000',
      salt: '100230',
    };

    const hash = await hashOffer(example, userA.flairContract);

    const signature = await signOffer(
      example,
      userA.signer,
      userA.flairContract
    );

    await userA.registryContract.registerProxy();

    await expect(
      userB.flairContract.fundOffer(
        ...prepareOfferArgs(example, signature, {
          target: userA.testERC721.address.toLowerCase(),
          data: targetSelector + targetExtradata.substr(2),
        }),
        {
          value: web3.utils.toWei('1.05'),
        }
      )
    )
      .to.emit(userA.flairContract, 'OfferFunded')
      .withArgs(hash, userA.signer.address, userB.signer.address, 1, 1);
  });
});
