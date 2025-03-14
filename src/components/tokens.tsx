'use client';

import { useState, useEffect } from 'react';
import Image from 'next/image';
import { useAccount } from 'wagmi';
import { useTokens } from '@/hooks/use-tokens';
import { Token } from '@/components/token';
import { ClaimPrize } from '@/components/claim-prize';
import { CompositeDialog } from '@/components/composite-dialog';
import { toast } from 'sonner';
import { Mint } from '@/components/mint';
import { Pool } from '@/components/pool';

export function Tokens() {
  const { address } = useAccount();
  const { data: tokens = [], isLoading, isFetching } = useTokens(address);
  const [showCompositeDialog, setShowCompositeDialog] = useState(false);
  const [selectedTokenId, setSelectedTokenId] = useState<number | null>(null);
  const [selectedPair, setSelectedPair] = useState<{
    source: number;
    target: number;
  } | null>(null);
  const [evolvedTokenId, setEvolvedTokenId] = useState<number | null>(null);

  // Reset the evolved token highlight after a delay
  useEffect(() => {
    if (evolvedTokenId !== null) {
      const timer = setTimeout(() => {
        setEvolvedTokenId(null);
      }, 5000); // Highlight for 5 seconds

      return () => clearTimeout(timer);
    }
  }, [evolvedTokenId]);

  const handleTokenSelect = (tokenId: number) => {
    // If the token is already selected, unselect it
    if (selectedTokenId === tokenId) {
      setSelectedTokenId(null);
      return;
    }

    // If no token is selected, select this one
    if (selectedTokenId === null) {
      setSelectedTokenId(tokenId);
      return;
    }

    // If another token is already selected, check if they can be combined
    const sourceToken = tokens.find((t) => t.id === selectedTokenId);
    const targetToken = tokens.find((t) => t.id === tokenId);

    if (!sourceToken || !targetToken) return;

    const sourceColorBand = sourceToken.attributes.find(
      (attr) => attr.trait_type === 'Arrows'
    )?.value;
    const targetColorBand = targetToken.attributes.find(
      (attr) => attr.trait_type === 'Arrows'
    )?.value;

    if (
      sourceColorBand &&
      targetColorBand &&
      sourceColorBand === targetColorBand
    ) {
      setSelectedPair({ source: selectedTokenId, target: tokenId });
      setShowCompositeDialog(true);
    } else {
      toast.error('Tokens must have the same number of arrows');
      // Select the new token instead
      setSelectedTokenId(tokenId);
    }
  };

  const handleCompositeComplete = (newEvolvedTokenId?: number) => {
    setShowCompositeDialog(false);
    setSelectedPair(null);
    setSelectedTokenId(null);

    // If we have an evolved token ID, set it to be highlighted
    if (newEvolvedTokenId) {
      setEvolvedTokenId(newEvolvedTokenId);
    }
  };

  if (isLoading) {
    return (
      <div className="grid grid-cols-3 gap-4">
        {[...Array(10)].map((_, i) => (
          <div key={i} className="relative aspect-square">
            <Image
              src="/loadingarrow.svg"
              alt="Loading"
              width={300}
              height={300}
              className="absolute inset-0 w-full h-full"
              priority={i < 4} // Prioritize loading first 4 images
            />
            <div className="absolute inset-0 bg-white/10 backdrop-blur-sm" />
            <div className="absolute inset-0 bg-white/10 backdrop-blur-sm animate-pulse" />
          </div>
        ))}
      </div>
    );
  }

  // Check if user has any winning tokens
  const winningToken = tokens.find((token) => token.isWinning);

  if (winningToken) {
    return <ClaimPrize token={winningToken} />;
  }

  const sourceToken = selectedPair
    ? tokens.find((t) => t.id === selectedPair.source) ?? null
    : null;
  const targetToken = selectedPair
    ? tokens.find((t) => t.id === selectedPair.target) ?? null
    : null;

  if (tokens.length === 0) {
    return (
      <div className="flex flex-col justify-center items-center p-6 space-y-6 text-center pt-0">
        <div className="relative w-64 h-64 mb-2">
          <Image
            src="/loadingarrow.svg"
            alt="Arrow"
            width={256}
            height={256}
            className="animate-pulse"
            priority
          />
        </div>

        <div className="space-y-3 max-w-xs">
          <div className="flex items-center gap-2 text-primary justify-center">
            <span className="text-sm font-medium">Current Prize Pool</span>
          </div>
          <div className="relative font-bold text-2xl pb-1">
            <Pool />
          </div>
          <p className="text-muted-foreground">
            Every mint contributes to the prize pool. Evolve your arrows by
            combining matching pairs. The first to find the higher arrow can
            claim the entire prize pool.
          </p>
        </div>

        <div className="flex flex-col items-center space-y-2">
          <Mint />
          <p className="text-xs text-muted-foreground">
            Minting costs 0.01 ETH for a pack of 10 arrows
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="relative p-4">
      {isFetching && (
        <div className="absolute inset-0 bg-background/50 backdrop-blur-sm z-10">
          <div className="text-sm text-muted-foreground p-2 text-center">
            Loading your arrows...
          </div>
        </div>
      )}
      <div className="grid grid-cols-3 gap-4">
        {tokens.map((token) => (
          <Token
            key={`token-${token.id}`}
            token={token}
            onSelect={handleTokenSelect}
            isSelected={selectedTokenId === token.id}
            isBurnToken={
              selectedPair?.target === token.id ||
              (selectedTokenId !== null &&
                selectedTokenId !== token.id &&
                evolvedTokenId !== token.id)
            }
            isEvolvedToken={evolvedTokenId === token.id}
          />
        ))}
      </div>

      <CompositeDialog
        open={showCompositeDialog}
        onOpenChange={setShowCompositeDialog}
        sourceToken={sourceToken}
        targetToken={targetToken}
        selectedPair={selectedPair}
        onCompositeComplete={handleCompositeComplete}
      />
    </div>
  );
}
