postgres = import_module("github.com/kurtosis-tech/postgres-package/main.star")
redis = import_module("github.com/kurtosis-tech/redis-package/main.star")

def run(plan, args):
    # start redis instance
    cache = redis.run(plan)

    # TODO: construct redis url from cache object
    redis_url = "redis://redis:6379"

    # start postgres database
    db = postgres.run(
        plan,
        user="colorstack",
        password="colorstack",
        launch_adminer=True)

    #TODO: construct url from db object
    colorstack_db_url = "postgresql://colorstack:colorstack@postgres:5432/colorstack"


    # Technically this can be done via running the oyster application but wanted to show you can setup db without running application
    # seed database
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
            image="tedim52/oyster:latest",
            cmd=["bash", "-c", "yarn && yarn db:migrate && yarn db:seed && yarn start"],
            env_vars={
                "DATABASE_URL": colorstack_db_url,
                "ADMIN_DASHBOARD_URL": "http://localhost:{0}".format(ADMIN_DASHBOARD_PORT),
                "API_URL": "http://localhost:{0}".format(API_PORT),
                "ENVIRONMENT": "development",
                "JWT_SECRET": "_",
                "SESSION_SECRET": "_",
                "REDIS_URL": redis_url,
                "STUDENT_PROFILE_URL": "http://localhost:{0}".format(STUDENT_PROFILE_PORT)
            },
            ports= {
                "admin_dashboard_frontend": PortSpec(
                    number=3000, # remix set to serve frontend on 3000
                    transport_protocol="TCP",
                    application_protocol="http"
                ),
                "student_profile_frontend": PortSpec(
                    number=4000, # remix set to servce frontend on 4000
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