'use client';

import { useState, useEffect, useRef } from 'react';
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { Button } from './ui/button';
import { useAccount } from 'wagmi';
import { ARROWS_CONTRACT } from '@/lib/contracts';
import { useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

interface CompositeProps {
  selectedTokens: number[];
  onCompositeComplete: () => void;
}

export function Composite({
  selectedTokens,
  onCompositeComplete,
}: CompositeProps) {
  const { address } = useAccount();
  const [isPending, setIsPending] = useState(false);
  const queryClient = useQueryClient();
  const successHandled = useRef(false);

  const { data: hash, writeContract } = useWriteContract();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  useEffect(() => {
    if (isSuccess && !successHandled.current) {
      successHandled.current = true;
      queryClient.invalidateQueries({ queryKey: ['tokens'] });
      onCompositeComplete();
      setTimeout(() => {
        toast.success('Successfully composited arrows!');
      }, 0);
      setIsPending(false);
    }
  }, [isSuccess, queryClient, onCompositeComplete]);

  const handleComposite = async () => {
    if (!address || selectedTokens.length !== 2) return;

    successHandled.current = false;
    setIsPending(true);
    try {
      await writeContract({
        ...ARROWS_CONTRACT,
        functionName: 'composite',
        args: [BigInt(selectedTokens[0]), BigInt(selectedTokens[1])],
      });
    } catch (error) {
      console.error('Composite error:', error);
      toast.error('Failed to composite arrows');
      setIsPending(false);
    }
  };

  const isLoading = isConfirming || isPending;
  const buttonText =
    isPending && !hash ? 'Waiting for approval...' : 'Composite Arrows';

  return (
    <Button
      onClick={handleComposite}
      disabled={isLoading || selectedTokens.length !== 2}
      className="bg-green-600 hover:bg-green-700 text-white min-w-[150px]"
    >
      {buttonText}
    </Button>
  );
}
