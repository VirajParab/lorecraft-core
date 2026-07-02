import { Composition } from "remotion";
import { ShotComposition } from "./ShotComposition";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="ShotComposition"
        component={ShotComposition}
        durationInFrames={150}
        fps={30}
        width={1920}
        height={1080}
        defaultProps={{
          backgroundUrl: "",
          sprites: [] as Array<{ url: string; x: number; y: number; scale: number }>,
        }}
      />
    </>
  );
};
