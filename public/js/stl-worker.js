importScripts('/js/vendor/three.min.js', '/js/vendor/STLLoader.js');

const loader = new THREE.STLLoader();

self.onmessage = async (e) => {
  const { id, url } = e.data;
  try {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const geometry = loader.parse(await res.arrayBuffer());

    if (!geometry.attributes.normal || geometry.attributes.normal.count === 0) {
      geometry.computeVertexNormals();
    }

    const position = geometry.attributes.position.array;
    const normal = geometry.attributes.normal ? geometry.attributes.normal.array : null;

    const transfer = [position.buffer];
    if (normal) transfer.push(normal.buffer);

    self.postMessage({ id, position, normal }, transfer);
  } catch (err) {
    self.postMessage({ id, error: String(err && err.message ? err.message : err) });
  }
};
