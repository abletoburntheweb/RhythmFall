class GameObject:
    def update(self):
        """
        Метод, который вызывается на каждом кадре.
        Должен быть переопределен в дочерних классах.
        """
        raise NotImplementedError("Метод update() должен быть реализован в дочернем классе.")