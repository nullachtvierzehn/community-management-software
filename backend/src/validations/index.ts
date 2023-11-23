import loginInput from "./login-input.js";
import registrationInput from "./registration-input.js";

export const jsonSchema = {
  $id: "validations",
  definitions: {
    loginInput,
    registrationInput,
  },
} as const;

export default jsonSchema;
