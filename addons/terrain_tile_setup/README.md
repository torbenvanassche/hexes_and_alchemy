# Terrain Tile Setup

Use this dock to configure the local slope profile stored on a tile scene.

1. Open a slope tile scene, such as `hex_grass_slope_half.tscn`.
2. Open **Terrain Tile Setup** in the right editor dock and click **Use Edited Scene Root**.
3. Set **Mesh high end** to the direction the unrotated mesh physically rises toward. This controls the mesh orientation, independently of its connections.
4. Mark the required placement edges as **Low** or **High**. A slope needs at least one of each. Use **Navigation only** for additional upper-level paths; they are purple and remain walkable when a neighbour matches their height, but they do not affect placement.
5. Compare the guides with the mesh, set the rise, click **Apply Profile**, and save the scene.

For a new terrain tile based on `HexBase`, click **Make Root a Slope Tile** first. The guide nodes are temporary editor children with no scene owner, so they are not saved into the tile.
