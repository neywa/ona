const _defaultFavicon =
    'https://www.google.com/s2/favicons?domain=redhat.com&sz=64';

const _faviconMap = {
  'Red Hat Blog':
      'https://www.google.com/s2/favicons?domain=redhat.com&sz=64',
  'Red Hat Developer':
      'https://www.google.com/s2/favicons?domain=developers.redhat.com&sz=64',
  'Kubernetes Blog':
      'https://www.google.com/s2/favicons?domain=kubernetes.io&sz=64',
  'CNCF Blog': 'https://www.google.com/s2/favicons?domain=cncf.io&sz=64',
  'Hacker News':
      'https://www.google.com/s2/favicons?domain=news.ycombinator.com&sz=64',
  'Reddit r/openshift':
      'https://www.google.com/s2/favicons?domain=reddit.com&sz=64',
};

String faviconUrl(String source) => _faviconMap[source] ?? _defaultFavicon;
