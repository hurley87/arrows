//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../interfaces/IArrows.sol";
import "./EightyColors.sol";
import "./Utilities.sol";

/**

 /////////   ARROWS   /////////
 //                             //
 //                             //
 //                             //
 //       ↗ ↗ ↗ ↗ ↗ ↗ ↗ ↗       //
 //       ↗ ↗ ↗ ↗ ↗ ↗ ↗ ↗       //
 //       ↗ ↗ ↗ ↗ ↗ ↗ ↗ ↗       //
 //       ↗ ↗ ↗ ↗ ↗ ↗ ↗ ↗       //
 //       ↗ ↗ ↗ ↗ ↗ ↗ ↗ ↗       //
 //       ↗ ↗ ↗ ↗ ↗ ↗ ↗ ↗       //
 //       ↗ ↗ ↗ ↗ ↗ ↗ ↗ ↗       //
 //       ↗ ↗ ↗ ↗ ↗ ↗ ↗ ↗       //
 //       ↗ ↗ ↗ ↗ ↗ ↗ ↗ ↗       //
 //       ↗ ↗ ↗ ↗ ↗ ↗ ↗ ↗       //
 //       ↗ ↗ ↗ ↗ ↗ ↗ ↗ ↗       //
 //                             //
 //                             //
 //                             //
 /////   POINT UP & RIGHT   /////

@title  ArrowsArt
@author VisualizeValue
@notice Renders the Arrows visuals.
*/
library ArrowsArt {

    /// @dev The semiperfect divisors of the 80 arrows.
    function DIVISORS() public pure returns (uint8[8] memory) {
        return [ 80, 40, 20, 10, 5, 4, 1, 0 ];
    }

    /// @dev The different color band sizes that we use for the art.
    function COLOR_BANDS() public pure returns (uint8[7] memory) {
        return [ 80, 60, 40, 20, 10, 5, 1 ];
    }

    /// @dev The gradient increment steps.
    function GRADIENTS() public pure returns (uint8[7] memory) {
        return [ 0, 1, 2, 5, 8, 9, 10 ];
    }

    /// @dev Load a arrow from storage and fill its current state settings.
    /// @param tokenId The id of the arrow to fetch.
    /// @param arrows The DB containing all arrows.
    function getArrow(
        uint256 tokenId, IArrows.Arrows storage arrows
    ) public view returns (IArrows.Arrow memory arrow) {
        IArrows.StoredArrow memory stored = arrows.all[tokenId];

        return getArrow(tokenId, stored.divisorIndex, arrows);
    }

    /// @dev Load a arrow from storage and fill its current state settings.
    /// @param tokenId The id of the arrow to fetch.
    /// @param divisorIndex The divisorindex to get.
    /// @param arrows The DB containing all arrows.
    function getArrow(
        uint256 tokenId, uint8 divisorIndex, IArrows.Arrows storage arrows
    ) public view returns (IArrows.Arrow memory arrow) {
        IArrows.StoredArrow memory stored = arrows.all[tokenId];
        stored.divisorIndex = divisorIndex; // Override in case we're fetching specific state.
        arrow.stored = stored;

        // Set up the source of randomness + seed for this Arrow.
        uint128 randomness = arrows.epochs[stored.epoch].randomness;
        arrow.seed = uint256(keccak256(abi.encodePacked(randomness, stored.seed))) % type(uint128).max;

        // Helpers
        arrow.isRoot = divisorIndex == 0;
        arrow.hasManyArrows = divisorIndex < 6;
        arrow.composite = !arrow.isRoot && divisorIndex < 7 ? stored.composites[divisorIndex - 1] : 0;

        // Token properties
        arrow.colorBand = colorBandIndex(arrow, divisorIndex);
        arrow.gradient = gradientIndex(arrow, divisorIndex);
        arrow.arrowsCount = DIVISORS()[divisorIndex];
        arrow.speed = uint8(2**(arrow.seed % 3));
        arrow.direction = uint8(arrow.seed % 2);
    }

    /// @dev Query the gradient of a given arrow at a certain arrow count.
    /// @param arrow The arrow we want to get the gradient for.
    /// @param divisorIndex The arrow divisor in question.
    function gradientIndex(IArrows.Arrow memory arrow, uint8 divisorIndex) public pure returns (uint8) {
        uint256 n = Utilities.random(arrow.seed, 'gradient', 100);

        return divisorIndex == 0
            ? n < 20 ? uint8(1 + (n % 6)) : 0
            : divisorIndex < 6
                ? arrow.stored.gradients[divisorIndex - 1]
                : 0;
    }

    /// @dev Query the color band of a given arrow at a certain arrow count.
    /// @param arrow The arrow we want to get the color band for.
    /// @param divisorIndex The arrow divisor in question.
    function colorBandIndex(IArrows.Arrow memory arrow, uint8 divisorIndex) public pure returns (uint8) {
        uint256 n = Utilities.random(arrow.seed, 'band', 120);

        return divisorIndex == 0
            ?   ( n > 80 ? 0
                : n > 40 ? 1
                : n > 20 ? 2
                : n > 10 ? 3
                : n >  4 ? 4
                : n >  1 ? 5
                : 6 )
            : divisorIndex < 6
                ? arrow.stored.colorBands[divisorIndex - 1]
                : 6;
    }

    /// @dev Generate indexes for the color slots of arrow parents (up to the EightyColors.COLORS themselves).
    /// @param divisorIndex The current divisorIndex to query.
    /// @param arrow The current arrow to investigate.
    /// @param arrows The DB containing all arrows.
    function colorIndexes(
        uint8 divisorIndex, IArrows.Arrow memory arrow, IArrows.Arrows storage arrows
    )
        public view returns (uint256[] memory)
    {
        uint8[8] memory divisors = DIVISORS();
        uint256 arrowsCount = divisors[divisorIndex];
        uint256 seed = arrow.seed;
        uint8 colorBand = COLOR_BANDS()[colorBandIndex(arrow, divisorIndex)];
        uint8 gradient = GRADIENTS()[gradientIndex(arrow, divisorIndex)];

        // If we're a composited arrow, we choose colors only based on
        // the slots available in our parents. Otherwise,
        // we choose based on our available spectrum.
        uint256 possibleColorChoices = divisorIndex > 0
            ? divisors[divisorIndex - 1] * 2
            : 80;

        // We initialize our index and select the first color
        uint256[] memory indexes = new uint256[](arrowsCount);
        indexes[0] = Utilities.random(seed, possibleColorChoices);

        // If we have more than one arrow, continue selecting colors
        if (arrow.hasManyArrows) {
            if (gradient > 0) {
                // If we're a gradient arrow, we select based on the color band looping around
                // the 80 possible colors
                for (uint256 i = 1; i < arrowsCount;) {
                    indexes[i] = (indexes[0] + (i * gradient * colorBand / arrowsCount) % colorBand) % 80;
                    unchecked { ++i; }
                }
            } else if (divisorIndex == 0) {
                // If we select initial non gradient colors, we just take random ones
                // available in our color band
                for (uint256 i = 1; i < arrowsCount;) {
                    indexes[i] = (indexes[0] + Utilities.random(seed + i, colorBand)) % 80;
                    unchecked { ++i; }
                }
            } else {
                // If we have parent arrows, we select our colors from their set
                for (uint256 i = 1; i < arrowsCount;) {
                    indexes[i] = Utilities.random(seed + i, possibleColorChoices);
                    unchecked { ++i; }
                }
            }
        }

        // We resolve our color indexes through our parent tree until we reach the root arrows
        if (divisorIndex > 0) {
            uint8 previousDivisor = divisorIndex - 1;

            // We already have our current arrow, but need the our parent state color indices
            uint256[] memory parentIndexes = colorIndexes(previousDivisor, arrow, arrows);

            // We also need to fetch the colors of the arrow that was composited into us
            IArrows.Arrow memory composited = getArrow(arrow.composite, previousDivisor, arrows);
            uint256[] memory compositedIndexes = colorIndexes(previousDivisor, composited, arrows);

            // Replace random indices with parent / root color indices
            uint8 count = divisors[previousDivisor];

            // We always select the first color from our parent
            uint256 initialBranchIndex = indexes[0] % count;
            indexes[0] = indexes[0] < count
                ? parentIndexes[initialBranchIndex]
                : compositedIndexes[initialBranchIndex];

            // If we don't have a gradient, we continue resolving from our parent for the remaining arrows
            if (gradient == 0) {
                for (uint256 i; i < arrowsCount;) {
                    uint256 branchIndex = indexes[i] % count;
                    indexes[i] = indexes[i] < count
                        ? parentIndexes[branchIndex]
                        : compositedIndexes[branchIndex];

                    unchecked { ++i; }
                }
            // If we have a gradient we base the remaining colors off our initial selection
            } else {
                for (uint256 i = 1; i < arrowsCount;) {
                    indexes[i] = (indexes[0] + (i * gradient * colorBand / arrowsCount) % colorBand) % 80;

                    unchecked { ++i; }
                }
            }
        }

        return indexes;
    }

    /// @dev Fetch all colors of a given Arrow.
    /// @param arrow The arrow to get colors for.
    /// @param arrows The DB containing all arrows.
    function colors(
        IArrows.Arrow memory arrow, IArrows.Arrows storage arrows
    ) public view returns (string[] memory, uint256[] memory) {
        // A fully composited arrow has no color.
        if (arrow.stored.divisorIndex == 7) {
            string[] memory zeroColors = new string[](1);
            uint256[] memory zeroIndexes = new uint256[](1);
            zeroColors[0] = '000';
            zeroIndexes[0] = 999;
            return (zeroColors, zeroIndexes);
        }

        // Fetch the indices on the original color mapping.
        uint256[] memory indexes = colorIndexes(arrow.stored.divisorIndex, arrow, arrows);

        // Map over to get the colors.
        string[] memory arrowColors = new string[](indexes.length);
        string[80] memory allColors = EightyColors.COLORS();

        // Always set the first color.
        arrowColors[0] = allColors[indexes[0]];

        // Resolve each additional check color via their index in EightyColors.COLORS.
        for (uint256 i = 1; i < indexes.length; i++) {
            arrowColors[i] = allColors[indexes[i]];
        }

        return (arrowColors, indexes);
    }

    /// @dev Get the number of arrows we should display per row.
    /// @param arrows The number of arrows in the piece.
    function perRow(uint8 arrows) public pure returns (uint8) {
        return arrows == 80
            ? 8
            : arrows >= 20
                ? 4
                : arrows == 10 || arrows == 4
                    ? 2
                    : 1;
    }

    /// @dev Get the X-offset for positioning arrow horizontally.
    /// @param arrows The number of arrows in the piece.
    function rowX(uint8 arrows) public pure returns (uint16) {
        return arrows <= 1
            ? 286
            : arrows == 5
                ? 304
                : arrows == 10 || arrows == 4
                    ? 268
                    : 196;
    }

    /// @dev Get the Y-offset for positioning arrow vertically.
    /// @param arrows The number of arrows in the piece.
    function rowY(uint8 arrows) public pure returns (uint16) {
        return arrows > 4
            ? 160
            : arrows == 4
                ? 268
                : arrows > 1
                    ? 304
                    : 286;
    }

    /// @dev Get the animation SVG snipped for an individual check of a piece.
    /// @param data The data object containing rendering settings.
    /// @param offset The index position of the check in question.
    /// @param allColors All available colors.
    function fillAnimation(
        ArrowRenderData memory data,
        uint256 offset,
        string[80] memory allColors
    ) public pure returns (bytes memory)
    {
        // We only pick 20 colors from our gradient to reduce execution time.
        uint8 count = 20;

        bytes memory values;

        // Reverse loop through our color gradient.
        if (data.arrow.direction == 0) {
            for (uint256 i = offset + 80; i > offset;) {
                values = abi.encodePacked(values, '#', allColors[i % 80], ';');
                unchecked { i-=4; }
            }
        // Forward loop through our color gradient.
        } else {
            for (uint256 i = offset; i < offset + 80;) {
                values = abi.encodePacked(values, '#', allColors[i % 80], ';');
                unchecked { i+=4; }
            }
        }

        // Add initial color as last one for smooth animations.
        values = abi.encodePacked(values, '#', allColors[offset]);

        // Render the SVG snipped for the animation
        return abi.encodePacked(
            '<animate ',
                'attributeName="fill" values="',values,'" ',
                'dur="',Utilities.uint2str(count * 2 / data.arrow.speed),'s" begin="animation.begin" ',
                'repeatCount="indefinite" ',
            '/>'
        );
    }

    /// @dev Generate the SVG code for all arrows in a given token.
    /// @param data The data object containing rendering settings.
    function generateArrows(ArrowRenderData memory data) public pure returns (bytes memory) {
        bytes memory arrowsBytes;
        string[80] memory allColors = EightyColors.COLORS();

        uint8 arrowsCount = data.count;
        for (uint8 i; i < arrowsCount; i++) {
            // Compute row settings.
            data.indexInRow = i % data.perRow;
            data.isNewRow = data.indexInRow == 0 && i > 0;

            // Compute offsets.
            if (data.isNewRow) data.rowY += data.spaceY;
            if (data.isNewRow && data.indent) {
                if (i == 0) {
                    data.rowX += data.spaceX / 2;
                }

                if (i % (data.perRow * 2) == 0) {
                    data.rowX -= data.spaceX / 2;
                } else {
                    data.rowX += data.spaceX / 2;
                }
            }
            string memory translateX = Utilities.uint2str(data.rowX + data.indexInRow * data.spaceX);
            string memory translateY = Utilities.uint2str(data.rowY);
            string memory color = data.colors[i];
            
            // Get animation bytes if needed
            bytes memory animationBytes = bytes('');
            if (!data.isBlack && !data.isStatic) {
                uint256 colorIndex = data.colorIndexes[i];
                animationBytes = fillAnimation(data, colorIndex, allColors);
            }

            // Render the current arrow.
            arrowsBytes = abi.encodePacked(arrowsBytes, abi.encodePacked(
                '<g transform="translate(', translateX, ', ', translateY, ')">',
                    '<g transform="translate(3, 3) scale(', data.scale, ')">',
                        '<path d="M25 43.77c2.12 0 6.68 6.9 8.68 6.17 1.99-.74 1.11-9 2.74-10.39 1.62-1.38 9.5-.93 10.55-.93 1.06 0-4.85-7.62-4.48-9.74.37-2.12 7.87-5.49 7.5-7.6-.37-2.12-8.54-2.68-9.6-4.54-1.06-1.86 2.55-9.33.93-10.72-1.62-1.38-8.24 3.53-10.23 2.79C29.08 8.07 27.12 0 25 0s-4.08 8.07-6.07 8.81c-1.99.74-8.61-4.17-10.23-2.79-1.62 1.38 1.98 8.85.93 10.72-1.06 1.86-9.24 2.42-9.6 4.54-.37 2.12 7.13 5.49 7.5 7.6.37 2.12-5.54 9.74-4.48 9.74 1.06 0 8.93-.45 10.55.93 1.62 1.38.75 9.65 2.74 10.39 1.99.74 6.56-6.17 8.68-6.17h-.01z" fill="#', color, '"',
                            animationBytes,
                        '/>',
                        '<path d="M25 15.12L15.41 24.34l2.86 2.73 4.68-4.53.005 12.36h4.14V22.54l4.7 4.53 2.8-2.73L25.08 15.12H25z" fill="black"/>',
                    '</g>',
                '</g>'
            ));
        }

        return arrowsBytes;
    }

    /// @dev Collect relevant rendering data for easy access across functions.
    /// @param arrow Our current arrow loaded from storage.
    /// @param arrows The DB containing all arrows.
    function collectRenderData(
        IArrows.Arrow memory arrow, IArrows.Arrows storage arrows
    ) public view returns (ArrowRenderData memory data) {
        // Carry through base settings.
        data.arrow = arrow;
        data.isBlack = arrow.stored.divisorIndex == 7;
        data.count = data.isBlack ? 1 : DIVISORS()[arrow.stored.divisorIndex];

        // Compute colors and indexes.
        (string[] memory colors_, uint256[] memory colorIndexes_) = colors(arrow, arrows);
        data.gridColor = '#000000';
        data.canvasColor = '#000000';
        data.colorIndexes = colorIndexes_;
        data.colors = colors_;

        // Compute positioning data.
        data.scale = data.count > 20 ? '0.528' : data.count > 1 ? '1.056' : '1.584';
        data.spaceX = data.count == 80 ? 36 : 72;
        data.spaceY = data.count > 20 ? 36 : 72;
        data.perRow = perRow(data.count);
        data.indent = data.count == 40;
        data.rowX = rowX(data.count);
        data.rowY = rowY(data.count);
    }

    /// @dev Generate the SVG code for rows in the 8x10 Arrows grid.
    function generateGridRow() public pure returns (bytes memory) {
        bytes memory row;
        for (uint256 i; i < 8; i++) {
            row = abi.encodePacked(
                row,
                '<use href="#square" x="', Utilities.uint2str(196 + i*36), '" y="160"/>'
            );
        }
        return row;
    }

    /// @dev Generate the SVG code for the entire 8x10 Arrows grid.
    function generateGrid() public pure returns (bytes memory) {
        bytes memory grid;
        for (uint256 i; i < 10; i++) {
            grid = abi.encodePacked(
                grid,
                '<use href="#row" y="', Utilities.uint2str(i*36), '"/>'
            );
        }

        return abi.encodePacked('<g id="grid" x="196" y="160">', grid, '</g>');
    }

    /// @dev Generate the complete SVG code for a given Arrow.
    /// @param arrow The arrow to render.
    /// @param arrows The DB containing all arrows.
    function generateSVG(
        IArrows.Arrow memory arrow, IArrows.Arrows storage arrows,
        bool isStatic
    ) public view returns (bytes memory) {
        ArrowRenderData memory data = collectRenderData(arrow, arrows);
        data.isStatic = isStatic;

        return abi.encodePacked(
            '<svg ',
                'viewBox="0 0 680 680" ',
                'fill="none" xmlns="http://www.w3.org/2000/svg" ',
                'style="width:100%;background:black;"',
            '>',
                '<defs>',
                    '<rect id="square" width="36" height="36" stroke="', data.gridColor, '"></rect>',
                    '<g id="row">', generateGridRow(), '</g>'
                '</defs>',
                '<rect width="680" height="680" fill="black"/>',
                '<rect x="188" y="152" width="304" height="376" fill="', data.canvasColor, '"/>',
                generateGrid(),
                generateArrows(data),
                !isStatic ? bytes('<rect width="680" height="680" fill="transparent"><animate attributeName="width" from="680" to="0" dur="0.2s" begin="click" fill="freeze" id="animation"/></rect>') : bytes(''),
            '</svg>'
        );
    }

    /// @dev Generate the complete SVG code for a given Arrow.
    /// @param arrow The arrow to render.
    /// @param arrows The DB containing all arrows.
    function generateSVG(
        IArrows.Arrow memory arrow, IArrows.Arrows storage arrows
    ) public view returns (bytes memory) {
        return generateSVG(arrow, arrows, false);
    }
}

/// @dev Bag holding all data relevant for rendering.
struct ArrowRenderData {
    IArrows.Arrow arrow;
    uint256[] colorIndexes;
    string[] colors;
    string canvasColor;
    string gridColor;
    string duration;
    string scale;
    uint32 seed;
    uint16 rowX;
    uint16 rowY;
    uint8 count;
    uint8 spaceX;
    uint8 spaceY;
    uint8 perRow;
    uint8 indexInRow;
    uint8 isIndented;
    bool isNewRow;
    bool isBlack;
    bool indent;
    bool isStatic;
}
