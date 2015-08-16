provider "nsone" {
}


variable "tld" {
    default = "terraform.testing.example"
}

resource "nsone_datasource" "api" {
    name = "terraform_example_api"
    sourcetype = "nsone_v1"
}

resource "nsone_datasource" "monitoring" {
    name = "terraform_example_monitoring"
    sourcetype = "nsone_monitoring"
}

resource "nsone_datafeed" "uswest1_feed" {
    name = "uswest1_feed"
    source_id = "${nsone_datasource.api.id}"
    config {
      label = "uswest1"
    }
}

resource "nsone_datafeed" "useast1_feed" {
    name = "useast1_feed"
    source_id = "${nsone_datasource.api.id}"
    config {
      label = "useast1"
    }
}

resource "nsone_zone" "tld" {
    zone = "${var.tld}"
    ttl = 60
}

resource "nsone_record" "www" {
    zone = "${nsone_zone.tld.zone}"
    domain = "www.${var.tld}"
    type = "CNAME" # Note, normally we'd use ALIAS here
    answers {
      answer = "example-elb-uswest1.aws.amazon.com"
      region = "uswest"
      meta {
        field = "up"
        feed = "${nsone_datafeed.uswest1_monitoring.id}"
      }
      meta {
        field = "high_watermark"
        feed = "${nsone_datafeed.uswest1_feed.id}"
      }
      meta {
        field = "low_watermark"
        feed = "${nsone_datafeed.uswest1_feed.id}"
      }
      meta {
        field = "connections"
        feed = "${nsone_datafeed.uswest1_feed.id}"
      }
    }
    answers {
      answer = "example-elb-useast1.aws.amazon.com"
      region = "useast"
      meta {
        field = "up"
        feed = "${nsone_datafeed.useast1_monitoring.id}"
      }
      meta {
        field = "high_watermark"
        feed = "${nsone_datafeed.useast1_feed.id}"
      }
      meta {
        field = "low_watermark"
        feed = "${nsone_datafeed.useast1_feed.id}"
      }
      meta {
        field = "connections"
        feed = "${nsone_datafeed.useast1_feed.id}"
      }
    }
    regions {
        name = "useast"
        georegion = "US-EAST"
    }
    regions {
        name = "uswest"
        georegion = "US-WEST"
    }
    filters {
        filter = "up"
        disabled = true
    }
    filters {
        filter = "shuffle"
    }
    filters {
        filter = "select_first_n"
        config {
          N = 3
        }
    }
}

resource "nsone_monitoringjob" "useast" {
    name = "useast"
    active = true
    regions = [ "lga" ]
    job_type = "tcp"
    frequency = 60
    rapid_recheck = true
    policy = "quorum"
    notes = "foo"
    config {
        send = "HEAD / HTTP/1.0\r\n\r\n"
        port = 80
        host = "85.214.55.250"
    }
}

resource "nsone_monitoringjob" "uswest" {
    name = "uswest"
    active = true
    regions = [ "sjc" ]
    job_type = "tcp"
    frequency = 60
    rapid_recheck = true
    policy = "quorum"
    notes = "foo"
    config {
        send = "HEAD / HTTP/1.0\r\n\r\n"
        port = 80
        host = "85.214.55.250"
    }
    rules {
        value = "200 OK"
        comparison =  "contains"
        key = "output"
    }
}

resource "nsone_datafeed" "uswest1_monitoring" {
    name = "uswest1_monitoring"
    source_id = "${nsone_datasource.monitoring.id}"
    config {
      jobid = "${nsone_monitoringjob.uswest.id}"
    }
}

resource "nsone_datafeed" "useast1_monitoring" {
    name = "useast1_monitoring"
    source_id = "${nsone_datasource.monitoring.id}"
    config {
      jobid = "${nsone_monitoringjob.useast.id}"
    }
}

