from typing import get_type_hints, Union
import sys


def _parse_bool(val: Union[str, bool]) -> bool:  # pylint: disable=E1136
    return val if type(val) == bool else val.lower() in ['true', 'yes', '1']


def _app_config_error(message, exit_code=1):
    sys.stderr.write('\n[error]: {}\n\n'.format(message))
    exit(exit_code)


# Learn more about using environment variables for app config in Python apps at https://doppler.com/blog/environment-variables-in-python
class AppConfigBase:
    '''
    Map environment variables to class fields according to these rules:
      - Field won't be parsed unless it has a type annotation
      - Field will be skipped if not in all caps
      - Class field and environment variable name are the same
    '''

    def __init__(self, env):
        for field in self.__annotations__:
            if not field.isupper():
                continue

            default_value = getattr(self, field, None)
            if default_value is None and env.get(field) is None:
                _app_config_error('The {} environment variable is required'.format(field))

            try:
                custom_parse_method = getattr(self, '_parse_{}'.format(field.lower()), None)
                var_type = get_type_hints(self)[field]
                raw_value = env.get(field, default_value)

                if custom_parse_method:
                    value = custom_parse_method(raw_value)
                    assert type(value) == var_type
                elif var_type == bool:
                    value = _parse_bool(env.get(field, default_value))
                else:
                    value = var_type(env.get(field, default_value))

                self.__setattr__(field, value)
            except ValueError:
                _app_config_error(
                    'Unable to cast value of "{}" to type "{}" for "{}" field'.format(
                        env[field], var_type, field
                    )
                )

    def __repr__(self):
        return str(self.__dict__)
