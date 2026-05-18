import os

# This is the NetBox configuration file.
# It is read from the container via the volume mount ./netbox/config:/etc/netbox/config
# Reference: https://netbox.readthedocs.io/en/stable/configuration/

ALLOWED_HOSTS = ['*']

DATABASE = {
    'NAME': os.environ.get('DB_NAME', 'netbox'),
    'USER': os.environ.get('DB_USER', 'netbox'),
    'PASSWORD': os.environ.get('DB_PASSWORD', ''),
    'HOST': os.environ.get('DB_HOST', 'netbox-db'),
    'PORT': os.environ.get('DB_PORT', '5432'),
    'CONN_MAX_AGE': 300,
}

REDIS = {
    'tasks': {
        'HOST': os.environ.get('REDIS_HOST', 'redis'),
        'PORT': int(os.environ.get('REDIS_PORT', 6379)),
        'DATABASE': int(os.environ.get('REDIS_DATABASE', 0)),
        'SSL': False,
    },
    'caching': {
        'HOST': os.environ.get('REDIS_HOST', 'redis'),
        'PORT': int(os.environ.get('REDIS_PORT', 6379)),
        'DATABASE': int(os.environ.get('REDIS_CACHE_DATABASE', 1)),
        'SSL': False,
    }
}

SECRET_KEY = os.environ.get('NETBOX_SECRET_KEY', 'CHANGE_ME_IN_ENV_FILE')

# Enable NAPALM integration for device automation (optional)
# NAPALM_USERNAME = os.environ.get('NAPALM_USERNAME', '')
# NAPALM_PASSWORD = os.environ.get('NAPALM_PASSWORD', '')
# NAPALM_ARGS = {}
# NAPALM_TIMEOUT = 30

# Pagination defaults
PAGINATE_COUNT = 50
MAX_PAGE_SIZE = 1000

# Default login URL
LOGIN_URL = '/login/'

# Session timeout (seconds)
LOGIN_TIMEOUT = None

# Enable API authentication
LOGIN_REQUIRED = True

# Logging
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
        },
    },
    'root': {
        'handlers': ['console'],
        'level': 'WARNING',
    },
}
