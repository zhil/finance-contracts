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

describe('Finance', () => {
  const web3Instance = new web3(web3.currentProvider);

  it('should successfully hash an offer', async () => {
    const { userA } = await setupTest();

    const example = {
      beneficiary: userA.signer.address.toLowerCase(),
      fundingOptions: generateFundingOptions({}),
      registry: userA.registryContract.address.toLowerCase(),
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: ZERO_ADDRESS,
      contributionValidatorSelector: '0x00000000',
      contributionValidatorExtradata: '0x',
      cancellationValidatorTarget: ZERO_ADDRESS,
      cancellationValidatorSelector: '0x00000000',
      cancellationValidatorExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '0',
    };

    const hash = await userA.financeContract.hashOffer(
      ...prepareOfferArgs(example)
    );

    expect(hashOffer(example, userA.financeContract)).to.equal(hash);
  });

  it('does not validate offer parameters with invalid contributionValidatorTarget', async () => {
    const { userA } = await setupTest();

    const example = {
      beneficiary: userA.signer.address.toLowerCase(),
      fundingOptions: generateFundingOptions({}),
      registry: userA.registryContract.address.toLowerCase(),
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: ZERO_ADDRESS,
      contributionValidatorSelector: '0x00000000',
      contributionValidatorExtradata: '0x',
      cancellationValidatorTarget: ZERO_ADDRESS,
      cancellationValidatorSelector: '0x00000000',
      cancellationValidatorExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '0',
    };

    expect(
      await userA.financeContract.validateOfferParameters(
        ...prepareOfferArgs(example)
      )
    ).to.equal(false);
  });

  it('validates valid authorization by signatureHex (sign_typed_data)', async () => {
    const { userA } = await setupTest();

    const example = {
      beneficiary: userA.signer.address.toLowerCase(),
      fundingOptions: generateFundingOptions({}),
      registry: userA.registryContract.address.toLowerCase(),
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: userA.financeContract.address.toLowerCase(),
      contributionValidatorSelector: '0x00000000',
      contributionValidatorExtradata: '0x',
      cancellationValidatorTarget: ZERO_ADDRESS,
      cancellationValidatorSelector: '0x00000000',
      cancellationValidatorExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '1000000000000',
    };

    const signature = await signOffer(
      example,
      userA.signer,
      userA.financeContract
    );
    const hash = hashOffer(example, userA.financeContract);

    expect(
      await userA.financeContract.validateOfferAuthorization(
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
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: userA.financeContract.address.toLowerCase(),
      contributionValidatorSelector: '0x00000000',
      contributionValidatorExtradata: '0x',
      cancellationValidatorTarget: ZERO_ADDRESS,
      cancellationValidatorSelector: '0x00000000',
      cancellationValidatorExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '1000000000000',
    };

    const hash = hashOffer(example, userA.financeContract);

    const resultOne = await userA.financeContract.getOfferFundingCost(
      userA.signer.address,
      hash,
      generateFundingOptions({}),
      1
    );
    const resultTwo = await userA.financeContract.getOfferFundingCost(
      userA.signer.address,
      hash,
      generateFundingOptions({}),
      2
    );
    const resultFive = await userA.financeContract.getOfferFundingCost(
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

    const contributionValidatorSelector =
      web3Instance.eth.abi.encodeFunctionSignature(
        'acceptContractAndSelectorAddUint32FillFromExtraData(bytes,address[5],uint8,uint256[5],bytes)'
      );
    const contributionValidatorExtradata =
      web3Instance.eth.abi.encodeParameters(
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
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: userA.staticValidators.address.toLowerCase(),
      contributionValidatorSelector,
      contributionValidatorExtradata,
      cancellationValidatorTarget: ZERO_ADDRESS,
      cancellationValidatorSelector: '0x00000000',
      cancellationValidatorExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '1000000000000',
    };

    const hash = await hashOffer(example, userA.financeContract);

    const signature = await signOffer(
      example,
      userA.signer,
      userA.financeContract
    );

    await userA.registryContract.registerProxy();

    await expect(
      userB.financeContract.fundOffer(
        ...prepareOfferArgs(example, signature, {
          target: userA.testERC721.address.toLowerCase(),
          data: targetSelector + targetData.substr(2),
        }),
        {
          value: web3.utils.toWei('1.01'),
        }
      )
    )
      .to.emit(userA.financeContract, 'OfferFunded')
      .withArgs(hash, userA.signer.address, userB.signer.address, 1, 1);
  });

  it('should successfully fund an offer and emit contribution event', async () => {
    const { userA, userB } = await setupTest();
    const nftId = Math.round(Math.random() * 1000000000);

    const targetSelector = web3Instance.eth.abi.encodeFunctionSignature(
      'mintExact(address,uint256)'
    );
    const targetData = web3Instance.eth.abi.encodeParameters(
      ['address', 'uint256'],
      [userB.signer.address.toLowerCase(), nftId]
    );

    const contributionValidatorSelector =
      web3Instance.eth.abi.encodeFunctionSignature(
        'acceptContractAndSelectorAddUint32FillFromExtraData(bytes,address[5],uint8,uint256[5],bytes)'
      );
    const contributionValidatorExtradata =
      web3Instance.eth.abi.encodeParameters(
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
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: userA.staticValidators.address.toLowerCase(),
      contributionValidatorSelector,
      contributionValidatorExtradata,
      cancellationValidatorTarget: ZERO_ADDRESS,
      cancellationValidatorSelector: '0x00000000',
      cancellationValidatorExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '1000000000000',
    };

    const signature = await signOffer(
      example,
      userA.signer,
      userA.financeContract
    );

    await userA.registryContract.registerProxy();

    await expect(
      userB.financeContract.fundOffer(
        ...prepareOfferArgs(example, signature, {
          target: userA.testERC721.address.toLowerCase(),
          data: targetSelector + targetData.substr(2),
        }),
        {
          value: web3.utils.toWei('1.01'),
        }
      )
    ).to.emit(userA.fundingContract, 'ContributionRegistered');
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

    const contributionValidatorSelector =
      web3Instance.eth.abi.encodeFunctionSignature(
        'acceptContractAndSelectorAddUint32FillFromExtraData(bytes,address[5],uint8,uint256[5],bytes)'
      );
    const contributionValidatorExtradata =
      web3Instance.eth.abi.encodeParameters(
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
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: userA.staticValidators.address.toLowerCase(),
      contributionValidatorSelector,
      contributionValidatorExtradata,
      cancellationValidatorTarget: ZERO_ADDRESS,
      cancellationValidatorSelector: '0x00000000',
      cancellationValidatorExtradata: '0x',
      maximumFill: '2',
      listingTime: '0',
      expirationTime: '1000000000000',
    };

    const signature = await signOffer(
      example,
      userA.signer,
      userA.financeContract
    );

    await userA.registryContract.registerProxy();

    await userB.financeContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userB.testERC721.address.toLowerCase(),
        data: targetSelector + targetData.substr(2),
      }),
      {
        value: web3.utils.toWei('1.01'),
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

    const contributionValidatorSelector =
      web3Instance.eth.abi.encodeFunctionSignature(
        'acceptContractAndSelectorAddUint32FillFromExtraData(bytes,address[5],uint8,uint256[5],bytes)'
      );
    const contributionValidatorExtradata =
      web3Instance.eth.abi.encodeParameters(
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
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: userA.staticValidators.address.toLowerCase(),
      contributionValidatorSelector,
      contributionValidatorExtradata,
      cancellationValidatorTarget: ZERO_ADDRESS,
      cancellationValidatorSelector: '0x00000000',
      cancellationValidatorExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '1000000000000',
    };

    const signature = await signOffer(
      example,
      userA.signer,
      userA.financeContract
    );

    await userA.registryContract.registerProxy();

    await expect(
      await userB.financeContract.fundOffer(
        ...prepareOfferArgs(example, signature, {
          target: userA.testERC721.address.toLowerCase(),
          data: targetSelector + targetData.substr(2),
        }),
        {
          value: web3.utils.toWei('1.01'),
        }
      )
    ).to.changeEtherBalances(
      [
        userA.financeContract,
        userA.treasuryContract,
        userA.fundingContract,
        userA.signer,
        userB.signer,
      ],
      [
        web3.utils.toWei('0'),
        web3.utils.toWei('0.01'),
        web3.utils.toWei('1'),
        web3.utils.toWei('0'),
        web3.utils.toWei('-1.01'),
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

    const contributionValidatorSelector =
      web3Instance.eth.abi.encodeFunctionSignature(
        'acceptContractAndSelectorAddUint32FillFromExtraData(bytes,address[5],uint8,uint256[5],bytes)'
      );
    const contributionValidatorExtradata =
      web3Instance.eth.abi.encodeParameters(
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
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: userA.staticValidators.address.toLowerCase(),
      contributionValidatorSelector,
      contributionValidatorExtradata,
      cancellationValidatorTarget: ZERO_ADDRESS,
      cancellationValidatorSelector: '0x00000000',
      cancellationValidatorExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '1000000000000',
    };

    const signature = await signOffer(
      example,
      userA.signer,
      userA.financeContract
    );

    await userA.registryContract.registerProxy();

    await userB.financeContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userA.testERC721.address.toLowerCase(),
        data: targetSelector + targetData.substr(2),
      }),
      {
        value: web3.utils.toWei('1.01'),
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

    const contributionValidatorSelector =
      web3Instance.eth.abi.encodeFunctionSignature(
        'acceptContractAndSelectorAddUint32FillFromExtraData(bytes,address[5],uint8,uint256[5],bytes)'
      );
    const contributionValidatorExtradata =
      web3Instance.eth.abi.encodeParameters(
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
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: userA.staticValidators.address.toLowerCase(),
      contributionValidatorSelector,
      contributionValidatorExtradata,
      cancellationValidatorTarget: ZERO_ADDRESS,
      cancellationValidatorSelector: '0x00000000',
      cancellationValidatorExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '1000000000000',
    };

    const signature = await signOffer(
      example,
      userA.signer,
      userA.financeContract
    );

    await userA.registryContract.registerProxy();

    await userB.financeContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userA.testERC721.address.toLowerCase(),
        data: targetSelector + targetData.substr(2),
      }),
      {
        value: web3.utils.toWei('1.01'),
      }
    );

    await increaseTime(50);

    await expect(
      await userA.fundingContract.releaseAllToBeneficiary()
    ).to.changeEtherBalances(
      [
        userA.financeContract,
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

    const contributionValidatorSelector =
      web3Instance.eth.abi.encodeFunctionSignature(
        'acceptContractAndSelectorAddUint32FillFromExtraData(bytes,address[5],uint8,uint256[5],bytes)'
      );
    const contributionValidatorExtradata =
      web3Instance.eth.abi.encodeParameters(
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
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: userA.staticValidators.address.toLowerCase(),
      contributionValidatorSelector,
      contributionValidatorExtradata,
      cancellationValidatorTarget: ZERO_ADDRESS,
      cancellationValidatorSelector: '0x00000000',
      cancellationValidatorExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '1000000000000',
    };

    const signature = await signOffer(
      example,
      userA.signer,
      userA.financeContract
    );

    await userA.registryContract.registerProxy();

    await userB.financeContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userA.testERC721.address.toLowerCase(),
        data: targetSelector + targetData.substr(2),
      }),
      {
        value: web3.utils.toWei('1.01'),
      }
    );

    await increaseTime(99);

    await expect(
      await userA.fundingContract.releaseAllToBeneficiary()
    ).to.changeEtherBalances(
      [
        userA.financeContract,
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

    const contributionValidatorSelector =
      web3Instance.eth.abi.encodeFunctionSignature(
        'acceptContractAndSelectorAddUint32FillFromExtraData(bytes,address[5],uint8,uint256[5],bytes)'
      );
    const contributionValidatorExtradata =
      web3Instance.eth.abi.encodeParameters(
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
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: userA.staticValidators.address.toLowerCase(),
      contributionValidatorSelector,
      contributionValidatorExtradata,
      cancellationValidatorTarget: ZERO_ADDRESS,
      cancellationValidatorSelector: '0x00000000',
      cancellationValidatorExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '1000000000000',
    };

    const signature = await signOffer(
      example,
      userA.signer,
      userA.financeContract
    );

    await userA.registryContract.registerProxy();

    await userB.financeContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userA.testERC721.address.toLowerCase(),
        data: targetSelector + targetData.substr(2),
      }),
      {
        value: web3.utils.toWei('1.01'),
      }
    );

    // TODO Find a more reliable way of asserting vesting schedule, this is flaky ATM!
    await increaseTime(99);

    await expect(
      await userA.fundingContract.releaseAllToBeneficiary()
    ).to.changeEtherBalances(
      [
        userA.financeContract,
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

    const contributionValidatorSelector =
      web3Instance.eth.abi.encodeFunctionSignature(
        'acceptContractAndSelectorAddUint32FillFromExtraData(bytes,address[5],uint8,uint256[5],bytes)'
      );
    const contributionValidatorExtradata =
      web3Instance.eth.abi.encodeParameters(
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
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: userA.staticValidators.address.toLowerCase(),
      contributionValidatorSelector,
      contributionValidatorExtradata,
      cancellationValidatorTarget: ZERO_ADDRESS,
      cancellationValidatorSelector: '0x00000000',
      cancellationValidatorExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '1000000000000',
    };

    const signature = await signOffer(
      example,
      userA.signer,
      userA.financeContract
    );

    await userA.registryContract.registerProxy();

    await userB.financeContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userA.testERC721.address.toLowerCase(),
        data: targetSelector + targetData.substr(2),
      }),
      {
        value: web3.utils.toWei('1.01'),
      }
    );

    await increaseTime(99);

    await expect(
      await userA.fundingContract.releaseAllToBeneficiary()
    ).to.changeEtherBalances(
      [
        userA.financeContract,
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

  it('should withdraw half vested payment when half vesting period, with upfront payment, no cliff period, no cliff payment', async () => {
    const { userA, userB } = await setupTest();
    const nftId = Math.round(Math.random() * 1000000000);

    const targetSelector = web3Instance.eth.abi.encodeFunctionSignature(
      'mintExact(address,uint256)'
    );
    const targetData = web3Instance.eth.abi.encodeParameters(
      ['address', 'uint256'],
      [userB.signer.address.toLowerCase(), nftId]
    );

    const contributionValidatorSelector =
      web3Instance.eth.abi.encodeFunctionSignature(
        'acceptContractAndSelectorAddUint32FillFromExtraData(bytes,address[5],uint8,uint256[5],bytes)'
      );
    const contributionValidatorExtradata =
      web3Instance.eth.abi.encodeParameters(
        ['address', 'bytes4', 'uint32'],
        [userA.testERC721.address.toLowerCase(), targetSelector, 1]
      );

    const example = {
      beneficiary: userA.signer.address.toLowerCase(),
      fundingOptions: generateFundingOptions({
        upfrontPayment: 1000, // 10%
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
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: userA.staticValidators.address.toLowerCase(),
      contributionValidatorSelector,
      contributionValidatorExtradata,
      cancellationValidatorTarget: ZERO_ADDRESS,
      cancellationValidatorSelector: '0x00000000',
      cancellationValidatorExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '1000000000000',
    };

    const signature = await signOffer(
      example,
      userA.signer,
      userA.financeContract
    );

    await userA.registryContract.registerProxy();

    await userB.financeContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userA.testERC721.address.toLowerCase(),
        data: targetSelector + targetData.substr(2),
      }),
      {
        value: web3.utils.toWei('1.01'),
      }
    );

    await increaseTime(99);

    await expect(
      await userA.fundingContract.releaseAllToBeneficiary()
    ).to.changeEtherBalances(
      [
        userA.financeContract,
        userA.treasuryContract,
        userA.fundingContract,
        userA.signer,
        userB.signer,
      ],
      [
        web3.utils.toWei('0'),
        web3.utils.toWei('0'),
        web3.utils.toWei('-0.55'),
        web3.utils.toWei('0.55'),
        web3.utils.toWei('0'),
      ]
    );

    expect(await userA.tokenContract.balanceOf(userA.signer.address)).to.equal(
      web3.utils.toWei('550')
    );
  });

  it('should withdraw half vested payment when half vesting period, with upfront payment, after cliff period, no cliff payment', async () => {
    const { userA, userB } = await setupTest();
    const nftId = Math.round(Math.random() * 1000000000);

    const targetSelector = web3Instance.eth.abi.encodeFunctionSignature(
      'mintExact(address,uint256)'
    );
    const targetData = web3Instance.eth.abi.encodeParameters(
      ['address', 'uint256'],
      [userB.signer.address.toLowerCase(), nftId]
    );

    const contributionValidatorSelector =
      web3Instance.eth.abi.encodeFunctionSignature(
        'acceptContractAndSelectorAddUint32FillFromExtraData(bytes,address[5],uint8,uint256[5],bytes)'
      );
    const contributionValidatorExtradata =
      web3Instance.eth.abi.encodeParameters(
        ['address', 'bytes4', 'uint32'],
        [userA.testERC721.address.toLowerCase(), targetSelector, 1]
      );

    const example = {
      beneficiary: userA.signer.address.toLowerCase(),
      fundingOptions: generateFundingOptions({
        upfrontPayment: 1000, // 10%
        cliffPeriod: 50,
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
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: userA.staticValidators.address.toLowerCase(),
      contributionValidatorSelector,
      contributionValidatorExtradata,
      cancellationValidatorTarget: ZERO_ADDRESS,
      cancellationValidatorSelector: '0x00000000',
      cancellationValidatorExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '1000000000000',
    };

    const signature = await signOffer(
      example,
      userA.signer,
      userA.financeContract
    );

    await userA.registryContract.registerProxy();

    await userB.financeContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userA.testERC721.address.toLowerCase(),
        data: targetSelector + targetData.substr(2),
      }),
      {
        value: web3.utils.toWei('1.01'),
      }
    );

    await increaseTime(149);

    await expect(
      await userA.fundingContract.releaseAllToBeneficiary()
    ).to.changeEtherBalances(
      [
        userA.financeContract,
        userA.treasuryContract,
        userA.fundingContract,
        userA.signer,
        userB.signer,
      ],
      [
        web3.utils.toWei('0'),
        web3.utils.toWei('0'),
        web3.utils.toWei('-0.55'),
        web3.utils.toWei('0.55'),
        web3.utils.toWei('0'),
      ]
    );

    expect(await userA.tokenContract.balanceOf(userA.signer.address)).to.equal(
      web3.utils.toWei('550')
    );
  });

  it('should withdraw half vested payment when half vesting period, with upfront payment, after cliff period, with cliff payment', async () => {
    const { userA, userB } = await setupTest();
    const nftId = Math.round(Math.random() * 1000000000);

    const targetSelector = web3Instance.eth.abi.encodeFunctionSignature(
      'mintExact(address,uint256)'
    );
    const targetData = web3Instance.eth.abi.encodeParameters(
      ['address', 'uint256'],
      [userB.signer.address.toLowerCase(), nftId]
    );

    const contributionValidatorSelector =
      web3Instance.eth.abi.encodeFunctionSignature(
        'acceptContractAndSelectorAddUint32FillFromExtraData(bytes,address[5],uint8,uint256[5],bytes)'
      );
    const contributionValidatorExtradata =
      web3Instance.eth.abi.encodeParameters(
        ['address', 'bytes4', 'uint32'],
        [userA.testERC721.address.toLowerCase(), targetSelector, 1]
      );

    const example = {
      beneficiary: userA.signer.address.toLowerCase(),
      fundingOptions: generateFundingOptions({
        upfrontPayment: 1000, // 10%
        cliffPeriod: 50,
        cliffPayment: 1000, // 10%
        vestingPeriod: 200,
        vestingRatio: web3.utils.toBN(1000000).toString(),
        priceBancorSupply: web3.utils.toBN(1000).toString(), // Initial Supply (e.g. Fills)
        priceBancorReserveBalance: web3.utils
          .toBN(web3.utils.toWei('1000'))
          .toString(), // Initial Reserve (e.g. ETH)
        priceBancorReserveRatio: web3.utils.toBN(1000000).toString(),
      }),
      registry: userA.registryContract.address.toLowerCase(),
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: userA.staticValidators.address.toLowerCase(),
      contributionValidatorSelector,
      contributionValidatorExtradata,
      cancellationValidatorTarget: ZERO_ADDRESS,
      cancellationValidatorSelector: '0x00000000',
      cancellationValidatorExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '1000000000000',
    };

    const signature = await signOffer(
      example,
      userA.signer,
      userA.financeContract
    );

    await userA.registryContract.registerProxy();

    await userB.financeContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userA.testERC721.address.toLowerCase(),
        data: targetSelector + targetData.substr(2),
      }),
      {
        value: web3.utils.toWei('1.01'),
      }
    );

    await increaseTime(149);

    await expect(
      await userA.fundingContract.releaseAllToBeneficiary()
    ).to.changeEtherBalances(
      [
        userA.financeContract,
        userA.treasuryContract,
        userA.fundingContract,
        userA.signer,
        userB.signer,
      ],
      [
        web3.utils.toWei('0'),
        web3.utils.toWei('0'),
        web3.utils.toWei('-0.6'),
        web3.utils.toWei('0.6'),
        web3.utils.toWei('0'),
      ]
    );

    expect(await userA.tokenContract.balanceOf(userA.signer.address)).to.equal(
      web3.utils.toWei('600')
    );
  });

  it('should refund remainder half vested payment when half vesting period, no upfront payment, no cliff period, no cliff payment', async () => {
    const { userA, userB } = await setupTest();
    const nftId = Math.round(Math.random() * 1000000000);

    const fundingTargetSelector = web3Instance.eth.abi.encodeFunctionSignature(
      'mintExact(address,uint256)'
    );
    const fundingTargetData = web3Instance.eth.abi.encodeParameters(
      ['address', 'uint256'],
      [userB.signer.address.toLowerCase(), nftId]
    );
    const cancellationTargetSelector =
      web3Instance.eth.abi.encodeFunctionSignature(
        'transferFrom(address,address,uint256)'
      );
    const cancellationTargetData = web3Instance.eth.abi.encodeParameters(
      ['address', 'address', 'uint256'],
      [
        userB.signer.address.toLowerCase(),
        userA.signer.address.toLowerCase(),
        nftId,
      ]
    );

    const contributionValidatorSelector =
      web3Instance.eth.abi.encodeFunctionSignature(
        'acceptContractAndSelectorAddUint32FillFromExtraData(bytes,address[5],uint8,uint256[5],bytes)'
      );
    const contributionValidatorExtradata =
      web3Instance.eth.abi.encodeParameters(
        ['address', 'bytes4', 'uint32'],
        [userA.testERC721.address.toLowerCase(), fundingTargetSelector, 1]
      );

    const cancellationValidatorSelector =
      web3Instance.eth.abi.encodeFunctionSignature(
        'acceptReturnERC721Any(bytes,address[5],uint8,uint256[5],bytes)'
      );
    const cancellationValidatorExtradata =
      web3Instance.eth.abi.encodeParameters(
        ['address'],
        [userA.testERC721.address.toLowerCase()]
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
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: userA.staticValidators.address.toLowerCase(),
      contributionValidatorSelector,
      contributionValidatorExtradata,
      cancellationValidatorTarget: userA.staticValidators.address.toLowerCase(),
      cancellationValidatorSelector,
      cancellationValidatorExtradata,
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '1000000000000',
    };

    const signature = await signOffer(
      example,
      userA.signer,
      userA.financeContract
    );

    await userA.registryContract.registerProxy();

    await userB.financeContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userA.testERC721.address.toLowerCase(),
        data: fundingTargetSelector + fundingTargetData.substr(2),
      }),
      {
        value: web3.utils.toWei('1.01'),
      }
    );

    // Approve creator's proxy to take back the NFT from taker
    const creatorProxy = await userB.registryContract.proxies(
      userA.signer.address
    );
    await userB.testERC721.setApprovalForAll(creatorProxy, true);

    const contributionId =
      (await userB.fundingContract.totalContributionsByHash(
        hashOffer(example, userB.financeContract)
      )) - 1;

    // TODO Find a more reliable way of asserting vesting schedule, this is flaky ATM!
    await increaseTime(98);

    await expect(
      await userB.financeContract.cancelFunding(
        ...prepareOfferArgs(
          example,
          signature,
          {
            target: userA.testERC721.address.toLowerCase(),
            data: cancellationTargetSelector + cancellationTargetData.substr(2),
          },
          [contributionId]
        )
      )
    ).to.changeEtherBalances(
      [
        userA.financeContract,
        userA.treasuryContract,
        userA.fundingContract,
        userA.signer,
        userB.signer,
      ],
      [
        web3.utils.toWei('0'),
        web3.utils.toWei('0'),
        web3.utils.toWei('-0.5'),
        web3.utils.toWei('0'),
        web3.utils.toWei('0.5'),
      ]
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

    const contributionValidatorSelector =
      web3Instance.eth.abi.encodeFunctionSignature(
        'acceptContractAndSelectorAddUint32FillFromExtraData(bytes,address[5],uint8,uint256[5],bytes)'
      );
    const contributionValidatorExtradata =
      web3Instance.eth.abi.encodeParameters(
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
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: userA.staticValidators.address.toLowerCase(),
      contributionValidatorSelector,
      contributionValidatorExtradata,
      cancellationValidatorTarget: ZERO_ADDRESS,
      cancellationValidatorSelector: '0x00000000',
      cancellationValidatorExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '1000000000000',
    };

    const signature = await signOffer(
      example,
      userA.signer,
      userA.financeContract
    );

    await userA.registryContract.registerProxy();

    await userB.financeContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userA.testERC721.address.toLowerCase(),
        data: targetSelector + targetData.substr(2),
      }),
      {
        value: web3.utils.toWei('1.01'),
      }
    );

    await increaseTime(99);

    await expect(
      await userA.fundingContract.releaseAllToBeneficiary()
    ).to.changeEtherBalances(
      [
        userA.financeContract,
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

  it('should correctly calculate releasable amount when offer cliff and vesting is fully finished', async () => {
    const { userA, userB } = await setupTest();

    const targetSelector = web3Instance.eth.abi.encodeFunctionSignature(
      'mintExact(address,uint256)'
    );
    const targetData = web3Instance.eth.abi.encodeParameters(
      ['address', 'uint256'],
      [userB.signer.address.toLowerCase(), 666]
    );

    const contributionValidatorSelector =
      web3Instance.eth.abi.encodeFunctionSignature(
        'acceptContractAndSelectorAddUint32FillFromExtraData(bytes,address[5],uint8,uint256[5],bytes)'
      );
    const contributionValidatorExtradata =
      web3Instance.eth.abi.encodeParameters(
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
        priceBancorSupply: web3.utils.toBN(1).toString(), // Initial Supply (e.g. Fills)
        priceBancorReserveBalance: web3.utils
          .toBN(web3.utils.toWei('3'))
          .toString(), // Initial Reserve (e.g. ETH)
        priceBancorReserveRatio: web3.utils.toBN(1000000).toString(),
      }),
      registry: userA.registryContract.address.toLowerCase(),
      creator: userA.signer.address.toLowerCase(),
      contributionValidatorTarget: userA.staticValidators.address.toLowerCase(),
      contributionValidatorSelector,
      contributionValidatorExtradata,
      cancellationValidatorTarget: ZERO_ADDRESS,
      cancellationValidatorSelector: '0x00000000',
      cancellationValidatorExtradata: '0x',
      maximumFill: '1',
      listingTime: '0',
      expirationTime: '1000000000000',
    };

    const signature = await signOffer(
      example,
      userA.signer,
      userA.financeContract
    );

    await userA.registryContract.registerProxy();

    await userB.financeContract.fundOffer(
      ...prepareOfferArgs(example, signature, {
        target: userA.testERC721.address.toLowerCase(),
        data: targetSelector + targetData.substr(2),
      }),
      {
        value: web3.utils.toWei('3.03'),
      }
    );

    await increaseTime(99);

    await expect(
      await userA.fundingContract.calculateReleasedAmountByContributionId(
        userA.signer.address,
        '0'
      )
    ).to.equal(web3.utils.toWei('3'));
  });
});
