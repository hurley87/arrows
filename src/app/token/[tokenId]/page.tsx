import { Metadata } from 'next';
import TokenPageClient from './token-page-client';
import { readContract } from '@wagmi/core';
import { createConfig, http } from 'wagmi';
import { base, baseSepolia } from 'wagmi/chains';
import { ARROWS_CONTRACT } from '@/lib/contracts';
import { type Transport } from 'viem';

const config = createConfig({
  chains: [base],
  transports: {
    [base.id]: http(process.env.NEXT_PUBLIC_BASE_RPC!),
    [baseSepolia.id]: http(process.env.NEXT_PUBLIC_BASE_SEPOLIA_RPC!),
  } as Record<number, Transport>,
});

const decodeBase64URI = (uri: string) => {
  const json = Buffer.from(uri.substring(29), 'base64').toString();
  return JSON.parse(json);
};

interface TokenPageProps {
  params: Promise<{
    tokenId: string;
  }>;
}

const appUrl = 'https://arrows.art';

async function getTokenMetadata(tokenId: string) {
  try {
    const tokenMetadata = await readContract(config, {
      address: ARROWS_CONTRACT.address,
      abi: ARROWS_CONTRACT.abi,
      functionName: 'tokenURI',
      args: [BigInt(tokenId)],
    });

    if (!tokenMetadata || tokenMetadata === '0x') {
      throw new Error('Token does not exist or has been burned');
    }

    return decodeBase64URI(tokenMetadata);
  } catch (error) {
    console.error('Error fetching token metadata:', error);
    throw new Error('Token does not exist or has been burned');
  }
}

export async function generateMetadata({
  params,
}: TokenPageProps): Promise<Metadata> {
  const { tokenId } = await params;

  try {
    const metadata = await getTokenMetadata(tokenId);

    const frame = {
      version: 'next',
      imageUrl: metadata.image,
      button: {
        title: 'View Token',
        action: {
          type: 'launch_frame',
          name: `Arrows Token #${tokenId}`,
          url: `${appUrl}/token/${tokenId}`,
          splashImageUrl: `${appUrl}/token/${tokenId}/splash`,
          splashBackgroundColor: '#000000',
        },
      },
    };

    return {
      title: `Arrows Token #${tokenId}`,
      openGraph: {
        title: `Arrows Token #${tokenId}`,
        description: 'View your Arrows token details.',
      },
      other: {
        'fc:frame': JSON.stringify(frame),
      },
    };
  } catch (error) {
    // Return a default frame for non-existent tokens
    const frame = {
      version: 'next',
      imageUrl: `${appUrl}/arrows.gif`,
      button: {
        title: 'View Token',
        action: {
          type: 'launch_frame',
          name: 'Token Not Found',
          url: `${appUrl}/token/${tokenId}`,
          splashImageUrl: `${appUrl}/splash.jpg`,
          splashBackgroundColor: '#000000',
        },
      },
    };

    return {
      title: `Token #${tokenId} Not Found`,
      openGraph: {
        title: `Token #${tokenId} Not Found`,
        description: 'This token does not exist or has been burned.',
      },
      other: {
        'fc:frame': JSON.stringify(frame),
      },
    };
  }
}

export default async function TokenPage({ params }: TokenPageProps) {
  const { tokenId } = await params;
  return <TokenPageClient params={{ tokenId }} />;
}
