const { expect } = require('chai');
const { v4: uuid } = require('uuid');
const web3 = require('web3');

const { setupTest } = require('../setup');
const { ZERO_ADDRESS } = require('../util');

describe('Registry', () => {
  it('should successfully register a proxy', async () => {
    const { userA } = await setupTest();

    await userA.registryContract.registerProxy();

    expect(
      await userA.registryContract.proxies(userA.signer.address)
    ).to.not.equal(ZERO_ADDRESS);
  });

  it('should successfully register a proxy for another account', async () => {
    const { userA, userB } = await setupTest();

    await userA.registryContract.registerProxyFor(userB.signer.address);

    expect(await userA.registryContract.proxies(userA.signer.address)).to.equal(
      ZERO_ADDRESS
    );

    expect(
      await userA.registryContract.proxies(userB.signer.address)
    ).to.not.equal(ZERO_ADDRESS);
  });
});
