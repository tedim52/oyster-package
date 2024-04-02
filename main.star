postgres = import_module("github.com/kurtosis-tech/postgres-package/main.star")
redis = import_module("github.com/kurtosis-tech/redis-package/main.star")

def run(
    plan, 
    smtp_username,
    smtp_password,
    smtp_host="smtp.gmail.com",
    admin_email="oyster@colorstack.org",
):
    """ Runs Oyster app

    Args:
        admin_email (string): email to use for admin user and initial member seeded to the db.
        smtp_host (string): the server address you are using to send emails. Example: smtp.gmail.com. 
        smtp_username (string): your email address that you'll be sending emails with. Example: you@gmail.com. 
        smtp_password (string): the password to your email account. 
    """
    # start redis instance
    cache = redis.run(plan)

    # TODO: update redis package to just return this url like postgres package
    redis_url = "redis://{0}:{1}".format(cache.hostname, cache.port_number)

    # start postgres database
    db = postgres.run(
        plan,
        user="colorstack",
        password="colorstack",
        database="colorstack",
        launch_adminer=True)
    plan.print(db.url)

    # This can be done via the oyster application but wanted to show a way to setup db without running app
    # setup db
    db_setup_sql_script = plan.render_templates(
        name="db-setup-script",
        config={
            "setup.sql": struct(
                template=read_file("./setup.sql"),
                data={},
            )
        }
    )
    result = plan.run_sh(
        run="psql {0} -f /root/setup.sql".format(db.url),
        image="postgres:latest",
        files={
            "/root": db_setup_sql_script,
        }
    )
    plan.print(result)

    # start oyster applications: API, Admin Dashboard, and Member Profile
    API_PORT=8080
    ADMIN_DASHBOARD_PORT=3001
    STUDENT_PROFILE_PORT=3000
    plan.add_service(
        name="oyster",
        config=ServiceConfig(
            image="tedim52/oysterapp:latest",
            cmd=["bash", "-c", "yarn db:migrate && yarn db:seed && yarn start"],
            env_vars={
                "DATABASE_URL": db.url,
                "ADMIN_DASHBOARD_URL": "http://localhost:{0}".format(ADMIN_DASHBOARD_PORT),
                "API_URL": "http://localhost:{0}".format(API_PORT),
                "ENVIRONMENT": "development",
                "JWT_SECRET": "_",
                "SESSION_SECRET": "_",
                "REDIS_URL": redis_url,
                "STUDENT_PROFILE_URL": "http://localhost:{0}".format(STUDENT_PROFILE_PORT),
                "SMTP_HOST": smtp_host,
                "SMTP_USERNAME": smtp_username,
                "SMTP_PASSWORD": smtp_password,
            },
            ports= {
                "admin_dashboard_frontend": PortSpec(
                    number=3000, # remix set to serve frontend on 3000
                    transport_protocol="TCP",
                    application_protocol="http"
                ),
                "student_profile_frontend": PortSpec(
                    number=4000, # remix set to serve frontend on 4000
                    transport_protocol="TCP",
                    application_protocol="http"
                ),
                "api": PortSpec(
                    number=API_PORT,
                    transport_protocol="TCP",
                    application_protocol="http"
                )
            },
        ),
    )
