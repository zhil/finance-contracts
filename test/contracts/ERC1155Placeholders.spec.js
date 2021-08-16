const { expect } = require('chai');
const { v4: uuid } = require('uuid');

const { setupTest } = require('../setup');

describe('ERC1155Placeholders', () => {
  it('should successfully mint a single token by ipfs hash', async () => {
    const { userA } = await setupTest();
    const ipfsHash = uuid();

    await userA.erc1155Placeholders.mint(
      userA.signer.address,
      ipfsHash,
      100,
      '0x'
    );

    expect(await userA.erc1155Placeholders.hashById(1)).to.equal(ipfsHash);
    expect(
      await userA.erc1155Placeholders.balanceOf(userA.signer.address, 1)
    ).to.equal(100);
  });

  it('should successfully mint a batch of tokens by ipfs hashes', async () => {
    const { userA } = await setupTest();
    const ipfsHash1 = uuid();
    const ipfsHash2 = uuid();
    const ipfsHash3 = uuid();

    await userA.erc1155Placeholders.mintBatch(
      userA.signer.address,
      [ipfsHash1, ipfsHash2, ipfsHash3],
      [100, 200, 300],
      '0x'
    );

    expect(await userA.erc1155Placeholders.hashById(1)).to.equal(ipfsHash1);
    expect(await userA.erc1155Placeholders.hashById(2)).to.equal(ipfsHash2);
    expect(await userA.erc1155Placeholders.hashById(3)).to.equal(ipfsHash3);
    expect(
      await userA.erc1155Placeholders.balanceOf(userA.signer.address, 1)
    ).to.equal(100);
    expect(
      await userA.erc1155Placeholders.balanceOf(userA.signer.address, 2)
    ).to.equal(200);
    expect(
      await userA.erc1155Placeholders.balanceOf(userA.signer.address, 3)
    ).to.equal(300);
  });

  it('should approve all for a user and allow transfer', async () => {
    const { userA, userB, userC } = await setupTest();
    const ipfsHash1 = uuid();
    const ipfsHash2 = uuid();
    const ipfsHash3 = uuid();

    await userA.erc1155Placeholders.mintBatch(
      userA.signer.address,
      [ipfsHash1, ipfsHash2, ipfsHash3],
      [100, 200, 300],
      '0x'
    );

    await userA.erc1155Placeholders.setApprovalForAll(
      userB.signer.address,
      true
    );

    await userB.erc1155Placeholders.safeTransferFrom(
      userA.signer.address,
      userC.signer.address,
      2,
      15,
      '0x'
    );

    expect(
      await userB.erc1155Placeholders.balanceOf(userC.signer.address, 2)
    ).to.equal(15);
  });

  it('should not allow transfer if not approved', async () => {
    const { userA, userB, userC } = await setupTest();
    const ipfsHash1 = uuid();
    const ipfsHash2 = uuid();
    const ipfsHash3 = uuid();

    await userA.erc1155Placeholders.mintBatch(
      userA.signer.address,
      [ipfsHash1, ipfsHash2, ipfsHash3],
      [100, 200, 300],
      '0x'
    );

    await expect(
      userB.erc1155Placeholders.safeTransferFrom(
        userA.signer.address,
        userC.signer.address,
        2,
        15,
        '0x'
      )
    ).to.be.revertedWith('ERC1155: caller is not owner nor approved');
  });
});
