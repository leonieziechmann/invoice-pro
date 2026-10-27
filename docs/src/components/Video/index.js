import useBaseUrl from '@docusaurus/useBaseUrl';
import styles from './styles.module.css';

/**
 * A showcase video of docs/static/video, built by scripts/showcase-videos
 * from tools/videos/scenes/<name>.toml (see MAINTENANCE.md).
 *
 * Usage in a page: <Video name="tour" title="invoice-pro in one minute" />
 */
export default function Video({name, title}) {
  const src = useBaseUrl(`/video/${name}.mp4`);
  const poster = useBaseUrl(`/video/${name}.jpg`);
  return (
    <figure className={styles.figure}>
      <video
        className={styles.video}
        controls
        muted
        playsInline
        preload="none"
        poster={poster}
        aria-label={title}>
        <source src={src} type="video/mp4" />
        <a href={src}>{title}</a>
      </video>
      {title && <figcaption className={styles.caption}>{title}</figcaption>}
    </figure>
  );
}
