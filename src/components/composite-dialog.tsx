'use client';

import { Button } from '@/components/ui/button';
import { Token } from '@/components/token';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { Composite } from '@/components/composite';

interface CompositeDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  sourceToken: {
    id: number;
    name: string;
    attributes: Array<{
      trait_type: string;
      value: string;
    }>;
  } | null;
  targetToken: {
    id: number;
    name: string;
    attributes: Array<{
      trait_type: string;
      value: string;
    }>;
  } | null;
  selectedPair: {
    source: number;
    target: number;
  } | null;
  onCompositeComplete: () => void;
}

export function CompositeDialog({
  open,
  onOpenChange,
  sourceToken,
  targetToken,
  selectedPair,
  onCompositeComplete,
}: CompositeDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="bg-black border-green-500/20 shadow-2xl !max-w-[425px] !h-[695px] !rounded-none flex flex-col">
        <div className="flex-1 flex flex-col items-center justify-center">
          <DialogHeader className="text-center">
            <DialogTitle className="text-white text-2xl mb-2">
              Composite Arrows
            </DialogTitle>
            <DialogDescription className="text-gray-400">
              Are you sure you want to composite these arrows together?
            </DialogDescription>
          </DialogHeader>

          {sourceToken && targetToken && (
            <div className="grid grid-cols-2 gap-8 py-8 px-4 w-full max-w-md">
              <div className="text-center source-arrow-container">
                <p className="text-sm text-gray-400 mb-4">Keep</p>
                <div className="relative">
                  <div className="absolute -inset-2 bg-green-500/20 rounded-xl blur-xl animate-pulse" />
                  <div className="absolute -inset-4 bg-green-500/10 rounded-2xl blur-2xl animate-pulse-slow" />
                  <Token token={sourceToken} onSelect={() => {}} />
                </div>
              </div>
              <div className="text-center target-arrow-container">
                <p className="text-sm text-gray-400 mb-4">Burn</p>
                <div className="relative">
                  <div className="absolute -inset-2 bg-red-500/20 rounded-xl blur-xl animate-pulse" />
                  <div className="absolute -inset-4 bg-red-500/10 rounded-2xl blur-2xl animate-pulse-slow" />
                  <Token token={targetToken} onSelect={() => {}} />
                </div>
              </div>
            </div>
          )}
        </div>

        <DialogFooter className="px-6 py-4 border-t border-gray-800">
          <Button
            variant="outline"
            onClick={() => onOpenChange(false)}
            className="text-white border-gray-700 hover:bg-gray-900"
          >
            Cancel
          </Button>
          <Composite
            selectedTokens={
              selectedPair ? [selectedPair.source, selectedPair.target] : []
            }
            onCompositeComplete={onCompositeComplete}
          />
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
