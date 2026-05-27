#include "wayplug.h"

#include <stddef.h>

int main(void)
{
    if (wayplug_abi_version() != WAYPLUG_ABI_VERSION) {
        return 1;
    }

    wayplug_host_interface host = {
        .size = sizeof(host),
        .version = WAYPLUG_ABI_VERSION,
        .userdata = NULL,
    };

    wayplug_server *server = wayplug_server_create(&host, NULL);
    if (server == NULL) {
        return 2;
    }

    if (wayplug_server_get_fd(server) != -1) {
        wayplug_server_destroy(server);
        return 3;
    }

    wayplug_server_destroy(server);
    return 0;
}
