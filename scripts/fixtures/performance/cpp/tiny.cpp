#include <iostream>

int main() {
    std::string name = "dog";
    int version = 1;

    std::cout << name << " v" << version << std::endl;

    for (int i = 0; i < 5; i++) {
        std::cout << "woof " << i << std::endl;
    }

    return 0;
}
