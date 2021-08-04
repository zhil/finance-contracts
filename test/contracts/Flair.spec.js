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
  increaseTime,
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
    const targetData = web3Instance.eth.abi.encodeParameters(
      ['address', 'uint256'],
      [userB.signer.address.toLowerCase(), 555]
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
          data: targetSelector + targetData.substr(2),
        }),
        {
          value: web3.utils.toWei('1.05'),
        }
      )
    )
      .to.emit(userA.flairContract, 'OfferFunded')
      .withArgs(hash, userA.signer.address, userB.signer.address, 1, 1);
  });

  it('should transfer NFT to funder when successfully funded an offer', async () => {
    const { userA, userB } = await setupTest();

    const targetSelector = web3Instance.eth.abi.encodeFunctionSignature(
      'mintExact(address,uint256)'
    );
    const targetData = web3Instance.eth.abi.encodeParameters(
      ['address', 'uint256'],
      [userB.signer.address.toLowerCase(), 888]
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
      maximumFill: '2',
      listingTime: '0',
      expirationTime: '1000000000000',
      salt: '100230',
    };

    const signature = await signOffer(
      example,
      userA.signer,
      userA.flairContract
    );

    await userA.registryContract.registerProxy();

    await userB.flairContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userB.testERC721.address.toLowerCase(),
        data: targetSelector + targetData.substr(2),
      }),
      {
        value: web3.utils.toWei('1.05'),
      }
    );

    expect(
      await userB.testERC721.ownerOf(
        web3Instance.eth.abi.encodeParameter('uint256', 888)
      )
    ).to.equal(userB.signer.address);
  });

  it('should successfully move the funds to funding contract when offer is funded', async () => {
    const { userA, userB } = await setupTest();

    const targetSelector = web3Instance.eth.abi.encodeFunctionSignature(
      'mintExact(address,uint256)'
    );
    const targetData = web3Instance.eth.abi.encodeParameters(
      ['address', 'uint256'],
      [userB.signer.address.toLowerCase(), 666]
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

    const signature = await signOffer(
      example,
      userA.signer,
      userA.flairContract
    );

    await userA.registryContract.registerProxy();

    await expect(
      await userB.flairContract.fundOffer(
        ...prepareOfferArgs(example, signature, {
          target: userA.testERC721.address.toLowerCase(),
          data: targetSelector + targetData.substr(2),
        }),
        {
          value: web3.utils.toWei('1.05'),
        }
      )
    ).to.changeEtherBalances(
      [
        userA.flairContract,
        userA.treasuryContract,
        userA.fundingContract,
        userA.signer,
        userB.signer,
      ],
      [
        web3.utils.toWei('0'),
        web3.utils.toWei('0.05'),
        web3.utils.toWei('1'),
        web3.utils.toWei('0'),
        web3.utils.toWei('-1.05'),
      ]
    );
  });

  it('should withdraw nothing if no upfront payment when during cliff period', async () => {
    const { userA, userB } = await setupTest();
    const nftId = Math.round(Math.random() * 1000000000);

    const targetSelector = web3Instance.eth.abi.encodeFunctionSignature(
      'mintExact(address,uint256)'
    );
    const targetData = web3Instance.eth.abi.encodeParameters(
      ['address', 'uint256'],
      [userB.signer.address.toLowerCase(), nftId]
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
        upfrontPayment: 0, // 0%
        cliffPeriod: 100,
        vestingPeriod: 200,
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

    const signature = await signOffer(
      example,
      userA.signer,
      userA.flairContract
    );

    await userA.registryContract.registerProxy();

    await userB.flairContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userA.testERC721.address.toLowerCase(),
        data: targetSelector + targetData.substr(2),
      }),
      {
        value: web3.utils.toWei('1.05'),
      }
    );

    await increaseTime(50);

    await expect(
      userA.fundingContract.releaseAllToBeneficiary()
    ).to.be.revertedWith('FUNDING/NOTHING_TO_RELEASE');

    expect(await userA.tokenContract.balanceOf(userA.signer.address)).to.equal(
      web3.utils.toWei('0')
    );
  });

  it('should withdraw upfront payment when during cliff period', async () => {
    const { userA, userB } = await setupTest();
    const nftId = Math.round(Math.random() * 1000000000);

    const targetSelector = web3Instance.eth.abi.encodeFunctionSignature(
      'mintExact(address,uint256)'
    );
    const targetData = web3Instance.eth.abi.encodeParameters(
      ['address', 'uint256'],
      [userB.signer.address.toLowerCase(), nftId]
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
        upfrontPayment: 1000, // 10%
        cliffPeriod: 100,
        vestingPeriod: 200,
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

    const signature = await signOffer(
      example,
      userA.signer,
      userA.flairContract
    );

    await userA.registryContract.registerProxy();

    await userB.flairContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userA.testERC721.address.toLowerCase(),
        data: targetSelector + targetData.substr(2),
      }),
      {
        value: web3.utils.toWei('1.05'),
      }
    );

    await increaseTime(50);

    await expect(
      await userA.fundingContract.releaseAllToBeneficiary()
    ).to.changeEtherBalances(
      [
        userA.flairContract,
        userA.treasuryContract,
        userA.fundingContract,
        userA.signer,
        userB.signer,
      ],
      [
        web3.utils.toWei('0'),
        web3.utils.toWei('0'),
        web3.utils.toWei('-0.1'),
        web3.utils.toWei('0.1'),
        web3.utils.toWei('0'),
      ]
    );

    expect(await userA.tokenContract.balanceOf(userA.signer.address)).to.equal(
      web3.utils.toWei('100')
    );
  });

  it('should withdraw upfront payment and cliff payment after cliff period', async () => {
    const { userA, userB } = await setupTest();
    const nftId = Math.round(Math.random() * 1000000000);

    const targetSelector = web3Instance.eth.abi.encodeFunctionSignature(
      'mintExact(address,uint256)'
    );
    const targetData = web3Instance.eth.abi.encodeParameters(
      ['address', 'uint256'],
      [userB.signer.address.toLowerCase(), nftId]
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
        upfrontPayment: 1000, // 10%
        cliffPeriod: 100,
        cliffPayment: 1500, // 15%
        vestingPeriod: 200,
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

    const signature = await signOffer(
      example,
      userA.signer,
      userA.flairContract
    );

    await userA.registryContract.registerProxy();

    await userB.flairContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userA.testERC721.address.toLowerCase(),
        data: targetSelector + targetData.substr(2),
      }),
      {
        value: web3.utils.toWei('1.05'),
      }
    );

    await increaseTime(100);

    await expect(
      await userA.fundingContract.releaseAllToBeneficiary()
    ).to.changeEtherBalances(
      [
        userA.flairContract,
        userA.treasuryContract,
        userA.fundingContract,
        userA.signer,
        userB.signer,
      ],
      [
        web3.utils.toWei('0'),
        web3.utils.toWei('0'),
        web3.utils.toWei('-0.25'),
        web3.utils.toWei('0.25'),
        web3.utils.toWei('0'),
      ]
    );

    expect(await userA.tokenContract.balanceOf(userA.signer.address)).to.equal(
      web3.utils.toWei('250')
    );
  });

  it('should withdraw cliff payment after cliff period when no upfront payment', async () => {
    const { userA, userB } = await setupTest();
    const nftId = Math.round(Math.random() * 1000000000);

    const targetSelector = web3Instance.eth.abi.encodeFunctionSignature(
      'mintExact(address,uint256)'
    );
    const targetData = web3Instance.eth.abi.encodeParameters(
      ['address', 'uint256'],
      [userB.signer.address.toLowerCase(), nftId]
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
        upfrontPayment: 0, // 0%
        cliffPeriod: 100,
        cliffPayment: 1500, // 15%
        vestingPeriod: 200,
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

    const signature = await signOffer(
      example,
      userA.signer,
      userA.flairContract
    );

    await userA.registryContract.registerProxy();

    await userB.flairContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userA.testERC721.address.toLowerCase(),
        data: targetSelector + targetData.substr(2),
      }),
      {
        value: web3.utils.toWei('1.05'),
      }
    );

    await increaseTime(100);

    await expect(
      await userA.fundingContract.releaseAllToBeneficiary()
    ).to.changeEtherBalances(
      [
        userA.flairContract,
        userA.treasuryContract,
        userA.fundingContract,
        userA.signer,
        userB.signer,
      ],
      [
        web3.utils.toWei('0'),
        web3.utils.toWei('0'),
        web3.utils.toWei('-0.15'),
        web3.utils.toWei('0.15'),
        web3.utils.toWei('0'),
      ]
    );

    expect(await userA.tokenContract.balanceOf(userA.signer.address)).to.equal(
      web3.utils.toWei('150')
    );
  });

  it('should withdraw half vested payment when half vesting period, no upfront payment, no cliff period, no cliff payment', async () => {
    const { userA, userB } = await setupTest();
    const nftId = Math.round(Math.random() * 1000000000);

    const targetSelector = web3Instance.eth.abi.encodeFunctionSignature(
      'mintExact(address,uint256)'
    );
    const targetData = web3Instance.eth.abi.encodeParameters(
      ['address', 'uint256'],
      [userB.signer.address.toLowerCase(), nftId]
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
        upfrontPayment: 0, // 0%
        cliffPeriod: 0,
        cliffPayment: 0, // 0%
        vestingPeriod: 200,
        vestingRatio: web3.utils.toBN(1000000).toString(),
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

    const signature = await signOffer(
      example,
      userA.signer,
      userA.flairContract
    );

    await userA.registryContract.registerProxy();

    await userB.flairContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userA.testERC721.address.toLowerCase(),
        data: targetSelector + targetData.substr(2),
      }),
      {
        value: web3.utils.toWei('1.05'),
      }
    );

    await increaseTime(100);

    await expect(
      await userA.fundingContract.releaseAllToBeneficiary()
    ).to.changeEtherBalances(
      [
        userA.flairContract,
        userA.treasuryContract,
        userA.fundingContract,
        userA.signer,
        userB.signer,
      ],
      [
        web3.utils.toWei('0'),
        web3.utils.toWei('0'),
        web3.utils.toWei('-0.5'),
        web3.utils.toWei('0.5'),
        web3.utils.toWei('0'),
      ]
    );

    expect(await userA.tokenContract.balanceOf(userA.signer.address)).to.equal(
      web3.utils.toWei('500')
    );
  });

  it('should successfully withdraw when offer cliff and vesting is fully finished', async () => {
    const { userA, userB } = await setupTest();

    const targetSelector = web3Instance.eth.abi.encodeFunctionSignature(
      'mintExact(address,uint256)'
    );
    const targetData = web3Instance.eth.abi.encodeParameters(
      ['address', 'uint256'],
      [userB.signer.address.toLowerCase(), 666]
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
        upfrontPayment: web3.utils.toBN(1000).toString(),
        cliffPayment: web3.utils.toBN(1500).toString(),
        cliffPeriod: 5,
        vestingRatio: web3.utils.toBN(1000000).toString(),
        vestingPeriod: 5,
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

    const signature = await signOffer(
      example,
      userA.signer,
      userA.flairContract
    );

    await userA.registryContract.registerProxy();

    await userB.flairContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userA.testERC721.address.toLowerCase(),
        data: targetSelector + targetData.substr(2),
      }),
      {
        value: web3.utils.toWei('1.05'),
      }
    );

    await increaseTime(100);

    await expect(
      await userA.fundingContract.releaseAllToBeneficiary()
    ).to.changeEtherBalances(
      [
        userA.flairContract,
        userA.treasuryContract,
        userA.fundingContract,
        userA.signer,
        userB.signer,
      ],
      [
        web3.utils.toWei('0'),
        web3.utils.toWei('0'),
        web3.utils.toWei('-1'),
        web3.utils.toWei('1'),
        web3.utils.toWei('0'),
      ]
    );

    expect(await userA.tokenContract.balanceOf(userA.signer.address)).to.equal(
      web3.utils.toWei('1000')
    );
  });
});
