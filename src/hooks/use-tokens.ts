import { useQuery } from '@tanstack/react-query';
import { readContract, writeContract } from '@wagmi/core';
import { createConfig } from 'wagmi';
import { chain, transport } from '@/lib/chain';
import { ARROWS_CONTRACT } from '@/lib/contracts';
import { type Address } from 'viem';
import { useState, useMemo } from 'react';

const config = createConfig({
  chains: [chain],
  transports: transport,
});

export interface Token {
  id: number;
  name: string;
  description?: string;
  image?: string;
  isWinning?: boolean;
  attributes: {
    trait_type: string;
    value: string;
  }[];
}

const decodeBase64URI = (uri: string) => {
  const json = Buffer.from(uri.substring(29), 'base64').toString();
  return JSON.parse(json);
};

export function useTokens(address: Address | undefined) {
  return useQuery({
    queryKey: ['tokens-balance', address],
    queryFn: async () => {
      if (!address) return { total: 0, tokenIds: [] };

      // Get user's token balance
      const balance = await readContract(config, {
        address: ARROWS_CONTRACT.address as Address,
        abi: ARROWS_CONTRACT.abi,
        functionName: 'balanceOf',
        args: [address],
      });

      const tokenIds: string[] = [];
      const balanceNum = Number(balance);

      // Get all token IDs without fetching metadata
      for (let i = 0; i < balanceNum; i++) {
        const tokenId = await readContract(config, {
          address: ARROWS_CONTRACT.address as Address,
          abi: ARROWS_CONTRACT.abi,
          functionName: 'tokenOfOwnerByIndex',
          args: [address, BigInt(i)],
        });
        // Convert BigInt to string to avoid serialization issues
        tokenIds.push(tokenId.toString());
      }

      return { total: balanceNum, tokenIds };
    },
    enabled: !!address,
  });
}

export function useTokensMetadata(
  address: Address | undefined,
  tokenIds: string[] = []
) {
  return useQuery({
    queryKey: ['tokens-metadata', address, tokenIds],
    queryFn: async () => {
      if (!address || tokenIds.length === 0) return [];

      const tokens: Token[] = [];

      // Get metadata for each token ID in the current page
      for (const tokenIdStr of tokenIds) {
        // Convert string back to BigInt for contract calls
        const tokenId = BigInt(tokenIdStr);

        // Get token metadata
        const tokenMetadata = await readContract(config, {
          address: ARROWS_CONTRACT.address as Address,
          abi: ARROWS_CONTRACT.abi,
          functionName: 'tokenURI',
          args: [tokenId],
        });

        // Check if token is winning
        const isWinning = await readContract(config, {
          address: ARROWS_CONTRACT.address as Address,
          abi: ARROWS_CONTRACT.abi,
          functionName: 'isWinningToken',
          args: [tokenId],
        });

        const token = {
          ...decodeBase64URI(tokenMetadata),
          id: Number(tokenId),
          isWinning,
        };

        tokens.push(token);
      }

      return tokens;
    },
    enabled: !!address && tokenIds.length > 0,
  });
}

export function usePaginatedTokens(address: Address | undefined, pageSize = 9) {
  const { data: balanceData, isLoading: isLoadingBalance } = useTokens(address);
  const [currentPage, setCurrentPage] = useState(1);

  const currentPageTokenIds = useMemo(() => {
    if (!balanceData?.tokenIds) return [];
    const start = (currentPage - 1) * pageSize;
    const end = start + pageSize;
    return balanceData.tokenIds.slice(start, end);
  }, [balanceData?.tokenIds, currentPage, pageSize]);

  const {
    data: tokensData,
    isLoading: isLoadingMetadata,
    isFetching,
  } = useTokensMetadata(address, currentPageTokenIds);

  const totalPages = useMemo(() => {
    if (!balanceData?.total) return 0;
    return Math.ceil(balanceData.total / pageSize);
  }, [balanceData?.total, pageSize]);

  return {
    tokens: tokensData || [],
    isLoading: isLoadingBalance || isLoadingMetadata,
    isFetching,
    pagination: {
      currentPage,
      totalPages,
      setPage: setCurrentPage,
      hasNextPage: currentPage < totalPages,
      hasPrevPage: currentPage > 1,
    },
  };
}

export function useClaimPrize() {
  return async (tokenId: number) => {
    try {
      const result = await writeContract(config, {
        address: ARROWS_CONTRACT.address as Address,
        abi: ARROWS_CONTRACT.abi,
        functionName: 'claimPrize',
        args: [BigInt(tokenId)],
      });
      return result;
    } catch (error) {
      console.error('Failed to claim prize:', error);
      throw error;
    }
  };
}
