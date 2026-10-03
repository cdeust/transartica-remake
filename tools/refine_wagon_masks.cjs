// MIT. Source art is read-only; guides are authored in source-pixel coordinates.
// API/default costs: https://docs.opencv.org/4.12.0/df/d6b/classcv_1_1segmentation_1_1IntelligentScissorsMB.html
// Dependencies: @techstark/opencv-js@5.0.0-release.1, @resvg/resvg-js@2.6.2, pngjs@7.0.0.
// Usage: node tools/refine_wagon_masks.cjs <dependencies> [subject] [output-directory] [guides-file]
const fs = require('node:fs');
const path = require('node:path');
const modules = path.resolve(process.argv[2], 'node_modules');
const { PNG } = require(path.join(modules, 'pngjs'));
const { Resvg } = require(path.join(modules, '@resvg/resvg-js'));
const guides = JSON.parse(fs.readFileSync(process.argv[5] || path.join(__dirname, 'wagon-mask-guides.json')));
const destination = path.resolve(process.argv[4] || path.join(__dirname, '../game/assets/boudoir/masks'));

function traceSegment(cv, image, pair, options) {
  const [a, b] = pair;
  const { radius, locked } = options;
  // Canvas clipping and authored low-contrast edges use their measured straight boundary.
  if (locked || pair.some(([x, y]) => x === image.cols || y === image.rows)) return pair;
  const x = Math.max(0, Math.min(a[0], b[0]) - radius);
  const y = Math.max(0, Math.min(a[1], b[1]) - radius);
  const right = Math.min(image.cols - 1, Math.max(a[0], b[0]) + radius);
  const bottom = Math.min(image.rows - 1, Math.max(a[1], b[1]) + radius);
  const roi = image.roi(new cv.Rect(x, y, right - x + 1, bottom - y + 1));
  const scissors = new cv.segmentation_IntelligentScissorsMB();
  const contour = new cv.Mat();
  // Retain the library's documented default features/weights; no tuned thresholds.
  scissors.applyImage(roi);
  scissors.buildMap(new cv.Point(a[0] - x, a[1] - y));
  scissors.getContour(new cv.Point(b[0] - x, b[1] - y), contour);
  const points = [];
  for (let i = 0; i < contour.data32S.length; i += 2) points.push([contour.data32S[i] + x, contour.data32S[i + 1] + y]);
  contour.delete();
  scissors.delete();
  roi.delete();
  return points;
}

function tracePaths(cv, image, guide) {
  return guide.contours.map((polygon, index) => {
    const points = [];
    for (let i = 0; i < polygon.length; i++) {
      const pair = [polygon[i], polygon[(i + 1) % polygon.length]];
      const locked = guide.lockedSegments?.[index]?.includes(i);
      points.push(...traceSegment(cv, image, pair, { radius: guide.searchRadius, locked }));
    }
    return `M${points.map(point => point.join(' ')).join('L')}Z`;
  }).join('');
}

function rasterize(paths, size, fill = 'white') {
  return PNG.sync.read(new Resvg(`<svg xmlns="http://www.w3.org/2000/svg" width="${size.width}" height="${size.height}" shape-rendering="crispEdges"><path fill="${fill}" fill-rule="evenodd" d="${paths}"/></svg>`).render().asPng());
}

function excludeOcclusions(matte, guide) {
  const exclusions = [];
  if (guide.background) exclusions.push(PNG.sync.read(new Resvg(`<svg xmlns="http://www.w3.org/2000/svg" width="${matte.width}" height="${matte.height}">${guide.background}</svg>`).render().asPng()));
  if (guide.excludeMask) exclusions.push(PNG.sync.read(new Resvg(fs.readFileSync(path.join(destination, guide.excludeMask + '.svg'))).render().asPng()));
  for (const exclusion of exclusions) {
    for (let i = 0; i < matte.data.length; i += 4) {
      if (!exclusion.data[i] || !exclusion.data[i + 3]) continue;
      matte.data[i] = matte.data[i + 1] = matte.data[i + 2] = matte.data[i + 3] = 0;
    }
  }
}

function vectorize(matte) {
  // Lossless binary source-pixel row runs, without contour simplification/resampling.
  const runs = [];
  let area = 0;
  for (let y = 0; y < matte.height; y++) {
    let start = -1;
    for (let x = 0; x <= matte.width; x++) {
      const white = x < matte.width && matte.data[(y * matte.width + x) * 4] === 255;
      if (white && start < 0) start = x;
      if (white || start < 0) continue;
      runs.push(`M${start} ${y}h${x - start}v1h${start - x}z`);
      area += x - start;
      start = -1;
    }
  }
  return { runs, area };
}

function generate(cv, guide) {
  const source = guide.name.startsWith('boudoir') ? 'captain-boudoir' : 'general-quarters';
  const png = PNG.sync.read(fs.readFileSync(path.join(__dirname, '../game/assets/boudoir', source + '.png')));
  const rgba = cv.matFromArray(png.height, png.width, cv.CV_8UC4, png.data);
  const image = new cv.Mat();
  cv.cvtColor(rgba, image, cv.COLOR_RGBA2BGR);
  const matte = rasterize(tracePaths(cv, image, guide), png);
  excludeOcclusions(matte, guide);
  const { runs, area } = vectorize(matte);
  if (!area) throw new Error('Empty mask: ' + guide.name);
  const output = `<svg xmlns="http://www.w3.org/2000/svg" width="${png.width}" height="${png.height}" viewBox="0 0 ${png.width} ${png.height}" shape-rendering="crispEdges">\n<!-- MIT. Source-pixel edge trace; tools/wagon-mask-guides.json and tasks/wagon-masks-20261002.md. -->\n<rect width="100%" height="100%" fill="#000"/>\n<path fill="#fff" d="${runs.join('')}"/>\n</svg>\n`;
  fs.writeFileSync(path.join(destination, guide.name + '.svg'), output);
  rgba.delete();
  image.delete();
  console.log(guide.name, png.width, png.height, area);
}

async function run() {
  const cv = await require(path.join(modules, '@techstark/opencv-js'));
  // Foreground occluders must exist before the subjects they obscure.
  const ordered = guides.filter(g => !g.excludeMask).concat(guides.filter(g => g.excludeMask));
  for (const guide of ordered) {
    if (process.argv[3] && guide.name !== process.argv[3]) continue;
    generate(cv, guide);
  }
}
run().catch(error => { console.error(error); process.exitCode = 1; });
