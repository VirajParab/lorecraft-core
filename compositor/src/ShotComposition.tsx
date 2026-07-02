import { AbsoluteFill, Img, useCurrentFrame, useVideoConfig } from "remotion";

type Sprite = {
  url: string;
  x: number;
  y: number;
  scale: number;
};

type ShotProps = {
  backgroundUrl: string;
  sprites: Sprite[];
  cameraScaleStart?: number;
  cameraScaleEnd?: number;
};

function lerp(a: number, b: number, t: number) {
  return a + (b - a) * t;
}

export const ShotComposition: React.FC<ShotProps> = ({
  backgroundUrl,
  sprites,
  cameraScaleStart = 1,
  cameraScaleEnd = 1.1,
}) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const t = frame / Math.max(durationInFrames - 1, 1);
  const scale = lerp(cameraScaleStart, cameraScaleEnd, t);

  return (
    <AbsoluteFill style={{ backgroundColor: "#0a0a12" }}>
      {backgroundUrl ? (
        <Img
          src={backgroundUrl}
          style={{
            width: "100%",
            height: "100%",
            objectFit: "cover",
            transform: `scale(${scale})`,
            transformOrigin: "center center",
          }}
        />
      ) : null}
      {sprites.map((sprite, i) => (
        <Img
          key={i}
          src={sprite.url}
          style={{
            position: "absolute",
            left: sprite.x,
            bottom: sprite.y,
            height: "70%",
            transform: `scale(${sprite.scale * scale})`,
            transformOrigin: "bottom center",
          }}
        />
      ))}
    </AbsoluteFill>
  );
};
