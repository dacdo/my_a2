name 'my_a2'

run_list 'my_a2::default'

# Where to find external cookbooks:
default_source :supermarket
cookbook 'my_a2', path: '..'
cookbook 'managed-automate2', path: '../../a2'
